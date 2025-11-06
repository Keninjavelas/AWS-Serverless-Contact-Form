terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- BACKEND INFRASTRUCTURE ---

# 1. Define the DynamoDB table
resource "aws_dynamodb_table" "contact_table" {
  name           = "ContactFormSubmissions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name    = "ContactForm-DynamoDB-Table"
    Project = "AWS Serverless Contact Form"
  }
}

# 2. A data block to get our AWS Account ID
data "aws_caller_identity" "current" {}

# 3. A data block to get our current AWS Region
data "aws_region" "current" {}

# 4. Define the IAM Role for our Lambda function
resource "aws_iam_role" "contact_lambda_role" {
  name = "ContactFormLambdaRole"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project = "AWS Serverless Contact Form"
  }
}

# 5. Define the CUSTOM permissions policy for our Lambda
resource "aws_iam_policy" "contact_lambda_policy" {
  name        = "ContactFormLambdaPolicy"
  description = "Allows Lambda to write to DynamoDB and send with SES"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      # Statement 1: Allow writing to our DynamoDB table
      {
        Action   = ["dynamodb:PutItem", "dynamodb:Scan"],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.contact_table.arn
      },
      # Statement 2: Allow sending email from our verified email address
      {
        Action = ["ses:SendEmail"],
        Effect = "Allow",
        Resource = "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:identity/${var.verified_email}"
      }
    ]
  })
}

# 6. ATTACH our custom policy to our new role
resource "aws_iam_role_policy_attachment" "custom_policy_attach" {
  role       = aws_iam_role.contact_lambda_role.name
  policy_arn = aws_iam_policy.contact_lambda_policy.arn
}

# 7. ATTACH the AWS-managed policy for logging to our new role
resource "aws_iam_role_policy_attachment" "logs_policy_attach" {
  role       = aws_iam_role.contact_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 8. Create a ZIP file of our Python code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda_package.zip"
}

# 9. Define the Lambda Function resource
resource "aws_lambda_function" "contact_lambda" {
  function_name = "ContactFormHandler"
  filename      = data.archive_file.lambda_zip.output_path
  role          = aws_iam_role.contact_lambda_role.arn
  handler       = "contact_form_handler.handler"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.contact_table.name
      VERIFIED_EMAIL = var.verified_email
    }
  }

  tags = {
    Project = "AWS Serverless Contact Form"
  }
}

# 10. Create a CloudWatch Log Group for our API
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/v2/api/${aws_lambda_function.contact_lambda.function_name}"
  retention_in_days = 30

  tags = {
    Project = "AWS Serverless Contact Form"
  }
}

# 11. Define the API Gateway (HTTP API v2)
resource "aws_apigatewayv2_api" "contact_api" {
  name          = "ContactFormAPI"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://${aws_cloudfront_distribution.frontend_cdn.domain_name}"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }

  tags = {
    Project = "AWS Serverless Contact Form"
  }
}

# 12. Define the "Stage" for the API
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.contact_api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 100
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId"
  }
}

# 13. Define the Integration between API Gateway and Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.contact_api.id
  integration_type       = "AWS_PROXY"
  payload_format_version = "2.0"
  integration_uri        = aws_lambda_function.contact_lambda.invoke_arn
}

# 14. Define the Route
resource "aws_apigatewayv2_route" "api_route" {
  api_id    = aws_apigatewayv2_api.contact_api.id
  route_key = "POST /submit"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 15. Give API Gateway Permission to run our Lambda
resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.contact_api.execution_arn}/*/*"
}

# --- FRONTEND INFRASTRUCTURE ---

# 16. Create the S3 bucket for our frontend website
resource "aws_s3_bucket" "frontend_bucket" {
  bucket_prefix = "serverless-contact-form-"

  tags = {
    Project = "AWS Serverless Contact Form"
  }
}

# 17. Configure the bucket for static website hosting
resource "aws_s3_bucket_website_configuration" "frontend_website_config" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }
}

# 18. Create a CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "OAC-ContactForm-S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 19. Create the CloudFront Distribution (our CDN)
resource "aws_cloudfront_distribution" "frontend_cdn" {
  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id                = "S3-ContactForm-Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-ContactForm-Origin"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project = "AWS Serverless Contact Form"
  }
}

# 20. The NEW, SECURE S3 Bucket Policy
resource "aws_s3_bucket_policy" "frontend_bucket_policy_secure" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "s3:GetObject",
        Effect    = "Allow",
        Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend_cdn.arn
          }
        }
      }
    ]
  })
}
# --- ADDITIONS FOR GUESTBOOK (READ FUNCTION) ---

# 21. Create a ZIP file for our *new* read_messages_handler.py
data "archive_file" "read_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/read_messages_handler.py"
  output_path = "${path.module}/read_lambda_package.zip"
}

# 22. Define the *new* Lambda Function for reading messages
resource "aws_lambda_function" "read_lambda" {
  function_name = "ReadMessagesHandler"
  
  # Use the new zip file
  filename      = data.archive_file.read_lambda_zip.output_path
  
  # RE-USE the same IAM role we already created
  role          = aws_iam_role.contact_lambda_role.arn
  
  # Point to the new file and handler
  handler       = "read_messages_handler.handler"
  
  source_code_hash = data.archive_file.read_lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 10

  # RE-USE the same environment variables
  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.contact_table.name
      VERIFIED_EMAIL = var.verified_email
    }
  }

  tags = {
    Project = "AWS Serverless Contact Form"
  }
}

# 23. Define the *new* Integration for the read_lambda
resource "aws_apigatewayv2_integration" "read_lambda_integration" {
  api_id                 = aws_apigatewayv2_api.contact_api.id
  integration_type       = "AWS_PROXY"
  payload_format_version = "2.0"
  integration_uri        = aws_lambda_function.read_lambda.invoke_arn
}

# 24. Define the *new* Route for "GET /messages"
resource "aws_apigatewayv2_route" "read_route" {
  api_id    = aws_apigatewayv2_api.contact_api.id
  
  # This is the new route key
  route_key = "GET /messages"
  
  # Target the new integration
  target    = "integrations/${aws_apigatewayv2_integration.read_lambda_integration.id}"
}

# 25. Give API Gateway Permission to run our *new* read_lambda
resource "aws_lambda_permission" "read_api_permission" {
  statement_id  = "AllowAPIGatewayInvokeRead"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.contact_api.execution_arn}/*/*"
}