# Fetch the existing S3 bucket
data "aws_s3_bucket" "pdf_storage" {
  bucket   = "pdfextractor-serverless"
}

# S3 bucket notification to trigger SQS when a PDF is uploaded
resource "aws_s3_bucket_notification" "pdf_upload_notification" {
  bucket   = data.aws_s3_bucket.pdf_storage.id

  queue {
    queue_arn     = aws_sqs_queue.pdf_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "upload/"
  }
}

## S3 Bucket in main region
#resource "aws_s3_bucket" "website" {
#  bucket   = "pdf2docx.vizeet.me"
#  acl      = "private"
#
#  cors_rule {
#    allowed_headers = ["*"]
#    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
#    allowed_origins = ["https://pdf2docx.vizeet.me"]
#    expose_headers  = ["ETag"]
#    max_age_seconds = 3000
#  }
#
#  website {
#    index_document = "index.html"
#    error_document = "error.html"
#  }
#}

## Modern CORS configuration
#resource "aws_s3_bucket_cors_configuration" "website" {
#  bucket = aws_s3_bucket.website.id
#
#  cors_rule {
#    allowed_headers = ["*"]
#    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
#    allowed_origins = ["https://pdf2docx.vizeet.me"]
#    expose_headers  = ["ETag"]
#    max_age_seconds = 3000
#  }
#}

# S3 Bucket with modern configuration
resource "aws_s3_bucket" "website" {
  bucket = "pdf2docx-vizeet-me"
  # Enable force_destroy for easier cleanup
  force_destroy = true
}

# Set bucket ownership controls (recommended)
resource "aws_s3_bucket_ownership_controls" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Create upload folder
resource "aws_s3_object" "upload_folder" {
  bucket = aws_s3_bucket.website.id
  key    = "upload/"
  content_type = "application/x-directory"
}

# Create processed folder
resource "aws_s3_object" "processed_folder" {
  bucket = aws_s3_bucket.website.id
  key    = "processed/"
  content_type = "application/x-directory"
}

locals {
  index_html = templatefile("${path.module}/templates/index.html.tpl", {
    api_endpoint = "https://${aws_apigatewayv2_api.presigned_url_api.id}.execute-api.us-east-2.amazonaws.com/prod/generate-url"
  })
}

# Separate website configuration
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}


resource "aws_s3_bucket_cors_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
    allowed_origins = ["https://pdf2docx.vizeet.me"]
    expose_headers  = ["ETag", "x-amz-server-side-encryption"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_object" "favicon" {
  bucket       = aws_s3_bucket.website.id
  key          = "favicon.ico"
  source       = "./src/favicon.ico"  # Path to your favicon file
  content_type = "image/x-icon"
  etag         = filemd5("./src/favicon.ico")
}

# Upload static files
resource "aws_s3_object" "index" {
  bucket        = aws_s3_bucket.website.id
  key           = "index.html"
  content = local.index_html
  content_type  = "text/html"
  #cache_control = "max-age=3600"
}

resource "aws_s3_object" "static_files" {
  for_each = fileset("./src/static/", "**/*")

  bucket        = aws_s3_bucket.website.id
  key           = "static/${each.value}"
  source        = "./src/static/${each.value}"
  etag          = filemd5("./src/static/${each.value}")
  content_type  = lookup(local.mime_types, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
  #cache_control = "max-age=31536000"
}

## Create app.js from template
#resource "aws_s3_object" "app_js" {
#  bucket       = aws_s3_bucket.website.id
#  key          = "static/app.js"
#  content_type = "application/javascript"
#  content      = templatefile("${path.module}/templates/app.js.tpl", {
#    api_gateway_url = aws_apigatewayv2_api.presigned_url_api.api_endpoint,
#    error           = "default_error_value",
#    response        = "default_response_value"
#  })
#  etag = filemd5("${path.module}/templates/app.js.tpl")
#}

resource "aws_s3_object" "app_js" {
  bucket = aws_s3_bucket.website.id
  key    = "static/app.js"
  content = templatefile("${path.module}/templates/app.js.tpl", {
    api_gateway_url = aws_apigatewayv2_api.presigned_url_api.api_endpoint
  })
  content_type  = "application/javascript"
  cache_control = "max-age=31536000"
}

locals {
  mime_types = {
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
    "png"  = "image/png",
    "jpg"  = "image/jpeg",
    "svg"  = "image/svg+xml",
    "json" = "application/json",
    "txt"  = "text/plain",
    "ico"  = "image/x-icon"
  }
}

# S3 Bucket Policy for CloudFront OAI
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.bucket_policy.json

  depends_on = [
    aws_s3_bucket_public_access_block.website
  ]
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

# Outputs
output "bucket_name" {
  value = data.aws_s3_bucket.pdf_storage.bucket
}
