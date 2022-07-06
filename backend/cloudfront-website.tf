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

# terraform's aws provider has no way to create an invalidation, so do it manually
resource "null_resource" "spelling_invalidator" {
	triggers = { for file in local.app_files : file => aws_s3_object.spelling[file].etag }
	provisioner "local-exec" {
		command = (var.automatic_invalidation ?
			"aws cloudfront create-invalidation --paths \"/*\" --distribution-id \"${aws_cloudfront_distribution.spelling.id}\"" :
			"echo The website changed. Remember to create a cache invalidation if necessary.")
	}
}
