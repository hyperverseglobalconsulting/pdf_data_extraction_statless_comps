data "aws_ecr_image" "pdf_splitter" {
  repository_name = aws_ecr_repository.pdf_splitter.name
  image_tag       = "latest"
}

resource "aws_lambda_function" "pdf_splitter" {
  function_name    = var.lambda_name_pdf_splitter
  package_type     = "Image"
  image_uri        = data.aws_ecr_image.pdf_splitter.image_manifest
  role             = aws_iam_role.pdf_splitter.arn
  memory_size      = 10240
  timeout          = 900

  environment {
    variables = {
      S3_BUCKET = var.bucket_name
      SQS_QUEUE_URL = var.sqs_queue_url
      TARGET_IMG_KEY_PREFIX=var.img_pages_key_prefix
    }
  }
}

resource "aws_iam_role" "pdf_splitter" {
  name = "pdf_splitter_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "pdf_splitter_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.pdf_splitter.name
}

resource "aws_s3_bucket_notification" "pdf_splitter_s3_bucket_notification" {
  bucket = var.bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.pdf_splitter.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.source_pdf_key_prefix
  }
}

resource "aws_iam_role_policy_attachment" "pdf_splitter_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.pdf_splitter.name

  policy {
    policy_json = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = [
            concat(var.bucket_arn, "/", var.source_pdf_key_prefix, "/*" )
            concat(var.bucket_arn, "/", var.img_pages_key_prefix, "/*" )
          ]
        }
      ]
    })
  }
}

