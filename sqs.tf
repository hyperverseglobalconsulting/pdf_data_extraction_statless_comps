resource "aws_sqs_queue" "pdf_queue" {
  name                       = "pdf-queue"
  visibility_timeout_seconds = 600
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "dlq" {
  name = "pdf-dlq"
}

resource "aws_sqs_queue_policy" "sqs_policy" {
  queue_url = aws_sqs_queue.pdf_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.pdf_queue.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = data.aws_s3_bucket.pdf_storage.arn
          }
        }
      }
    ]
  })
}

output "sqs_queue_url" {
  value = aws_sqs_queue.pdf_queue.id
}

output "sqs_dlq_queue_url" {
  value = aws_sqs_queue.dlq.id
}

