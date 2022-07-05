#### NOTES ####
# cloudfront distribution => origin access identity (OAI)
#  (origin = s3 bucket)
#  (default root object = index.html)
# s3 bucket (policy to allow OAI to GET)
# lambda => role (policy to allow logs, s3 PUT, and cloudfront invalidation)
# event bridge rule => target (call lambda daily, needs lambda permission)

provider "aws" {
	region = "us-east-1"
}

#### s3 bucket ####

resource "aws_s3_bucket" "spelling" {
	bucket = "spelling-jeoparbee-terraform"
	tags = {
		Name = "Spelling Jeoparbee website bucket"
	}
}

resource "aws_s3_bucket_acl" "spelling" {
	bucket = aws_s3_bucket.spelling.id
	acl = "private"
}

resource "aws_s3_bucket_public_access_block" "spelling" {
	bucket = aws_s3_bucket.spelling.id
	block_public_acls = true
	block_public_policy = true
	ignore_public_acls = true
	restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "spelling" {
	bucket = aws_s3_bucket.spelling.id
	policy = jsonencode({
		Version = "2012-10-17"
		Statement = [{
			Effect = "Allow"
			Action = "s3:GetObject"
			Resource = "${aws_s3_bucket.spelling.arn}/*"
			Principal = { 
				AWS = aws_cloudfront_origin_access_identity.spelling.iam_arn
			}
		}]
	})
}

locals {
	app_files = [
		"../frontend/public/index.html",
		"../frontend/public/bundle.js",
	]
	mime_types = {
		"html" = "text/html"
		"js" = "text/javascript"
	}
}

resource "aws_s3_object" "spelling" {
	for_each = toset(local.app_files)
	bucket = aws_s3_bucket.spelling.id
	key = basename(each.value)
	source = each.value
	content_type = lookup(local.mime_types, 
		regex("\\.?([^\\.]*)$", each.value)[0], 
		"application/octet-stream")
	etag = filemd5(each.value)
}

resource "null_resource" "spelling_invalidator" {
	triggers = { for file in local.app_files : file => aws_s3_object.spelling[file].etag }
	provisioner "local-exec" {
		# TODO: use aws cli to do invalidation automatically if some input variable set
		command = "echo The website changed. Remember to create a cache invalidation."
	}
}

#### cloudfront website ####

locals {
	# bucket_regional_domain_name isn't actually regional for us-east-1, but this probably was unnecessary:
	spelling_s3_regional_name = "${aws_s3_bucket.spelling.id}.s3.${aws_s3_bucket.spelling.region}.amazonaws.com"
	caching_optimized_policy = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

resource "aws_cloudfront_origin_access_identity" "spelling" {
	comment = "Spelling Jeoparbee (Terraform) OAI"
}

resource "aws_cloudfront_distribution" "spelling" {
	default_root_object = "index.html"
	enabled = true
	price_class = "PriceClass_100"
	
	origin {
		domain_name = local.spelling_s3_regional_name
		origin_id = local.spelling_s3_regional_name
		s3_origin_config {
			origin_access_identity = aws_cloudfront_origin_access_identity.spelling.cloudfront_access_identity_path
		}
	}

	default_cache_behavior {
		allowed_methods = ["GET", "HEAD"]
		cached_methods = ["GET", "HEAD"]
		cache_policy_id = local.caching_optimized_policy
		compress = true
		target_origin_id = local.spelling_s3_regional_name
		viewer_protocol_policy = "allow-all"
	}

	restrictions {
		geo_restriction {
			restriction_type = "none"
		}
	}

	viewer_certificate {
		cloudfront_default_certificate = true
	}
}

output "spelling_dns_name" {
	value = aws_cloudfront_distribution.spelling.domain_name
	description = "Domain name of the CloudFront distribution"
}

#### gamedata fetching lambda ####

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

#### cron job to run lambda daily ####

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