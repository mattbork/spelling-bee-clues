

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
