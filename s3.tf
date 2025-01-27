# Fetch the existing S3 bucket
data "aws_s3_bucket" "pdf_storage" {
  bucket = "pdfextractor-serverless"
}

# S3 bucket notification to trigger SQS when a PDF is uploaded
resource "aws_s3_bucket_notification" "pdf_upload_notification" {
  bucket = data.aws_s3_bucket.pdf_storage.id

  queue {
    queue_arn     = aws_sqs_queue.pdf_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "upload/"
  }
}

# Outputs
output "bucket_name" {
  value = data.aws_s3_bucket.pdf_storage.bucket
}
