provider "aws" {
	region = "us-east-1"
}

variable "automatic_invalidation" {
	description = "Automatically create an invalidation for the CloudFront distribution if true"
	type = bool
	default = false
}

output "spelling_dns_name" {
	value = aws_cloudfront_distribution.spelling.domain_name
	description = "Domain name of the CloudFront distribution"
}
