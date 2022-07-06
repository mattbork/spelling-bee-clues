resource "aws_iam_role" "spelling_lambda" {
	name = "spelling_lambda_role"
	description = "Role for lambda that fetches Spelling Bee gameData"
	assume_role_policy = jsonencode({
		Version = "2012-10-17",
		Statement = [{
			Action = "sts:AssumeRole"
			Effect = "Allow"
			Principal = { Service = "lambda.amazonaws.com" }
			Sid = ""
		}]
	})
}

resource "aws_iam_role_policy" "spelling_lambda" {
	name = "spelling_lambda_policy"
	role = aws_iam_role.spelling_lambda.id
	policy = jsonencode({
		Version = "2012-10-17"
		Statement = [{
			Effect = "Allow"
			Action = [
				"logs:CreateLogGroup",
				"logs:CreateLogStream",
				"logs:PutLogEvents",
			]
			Resource = "arn:aws:logs:*:*:*"
		}, {
			Effect = "Allow"
			Action = "s3:PutObject"
			Resource = "${aws_s3_bucket.spelling.arn}/*"
		}, {
			Effect = "Allow"
			Action = "cloudfront:CreateInvalidation"
			Resource = aws_cloudfront_distribution.spelling.arn
		}]
	})
}

data "archive_file" "spelling_lambda" {
	type = "zip"
	source_file = "spelling-lambda.js"
	output_path = "spelling-lambda.zip"
}

resource "aws_lambda_function" "spelling_lambda" {
	function_name = "spelling-fetch-gamedata"
	description = "Scrape Spelling Bee for gameData"
	role = aws_iam_role.spelling_lambda.arn

	filename = data.archive_file.spelling_lambda.output_path
	handler = "spelling-lambda.handler"
	source_code_hash = data.archive_file.spelling_lambda.output_base64sha256
	runtime = "nodejs16.x"
	timeout = 10

	memory_size = 128
	ephemeral_storage {
		size = 512
	}

	environment {
		variables = {
			bucket_name = "${aws_s3_bucket.spelling.id}"
			distribution_id = "${aws_cloudfront_distribution.spelling.id}"
		}
	}
}

resource "aws_lambda_permission" "cron_job" {
	action = "lambda:InvokeFunction"
	function_name = aws_lambda_function.spelling_lambda.function_name
	principal = "events.amazonaws.com"
	source_arn = aws_cloudwatch_event_rule.cron_job.arn
}

resource "aws_cloudwatch_event_rule" "cron_job" {
	name = "spelling-cron-job"
	description = "Daily 3:05 am EST run of lambda to fetch spelling gamedata"
	schedule_expression = "cron(5 7 * * ? *)"
}

resource "aws_cloudwatch_event_target" "cron_job" {
	arn = aws_lambda_function.spelling_lambda.arn
	rule = aws_cloudwatch_event_rule.cron_job.name
	retry_policy {
		maximum_event_age_in_seconds = 300
		maximum_retry_attempts = 1
	}
}
