# This output will print the final "invoke URL" of our API
# after we deploy it. We'll use this in our frontend JavaScript.
output "api_endpoint_url" {
  description = "The base URL for the contact form API"
  value       = aws_apigatewayv2_stage.api_stage.invoke_url
}
output "frontend_website_url" {
  description = "The public URL for the frontend website"
  value       = "https://${aws_cloudfront_distribution.frontend_cdn.domain_name}"
}
output "frontend_bucket_name" {
  description = "The name of the S3 bucket hosting the frontend"
  value       = aws_s3_bucket.frontend_bucket.id
}