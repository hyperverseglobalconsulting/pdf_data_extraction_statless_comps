data "aws_ecr_image" "page_extractor" {
  repository_name = resource.aws_ecr_repository.page_extractor.name
  image_tag       = "latest"
}

resource "aws_lambda_function" "page_extractor" {
  function_name    = var.lambda_name_page_extractor
  package_type     = "Image"
  image_uri        = data.aws_ecr_image.page_extractor.image_manifest
  role             = aws_iam_role.page_extractor.arn
  memory_size      = 10240
  timeout          = 900

  environment {
    variables = {
      S3_BUCKET = var.bucket
      SQS_QUEUE_URL = sqs_queue_url
      TARGET_IMG_KEY_PREFIX=var.img_pages_key_prefix
      BATCH_SIZE=1
      TARGET_KEY_PREFIX=var.opensearch_data_key_prefix
      TEMP_KEY_PREFIX=var.temp_images_key_prefix
      MASKED_KEY_PREFIX=var.masked_images_key_prefix
      TABLE_CORNERS_KEY_PREFIX=var.table_corners_key_prefix
      SQS_QUEUE_URL=var.sqs_queue_url
    }
  }
}

resource "aws_iam_role" "page_extractor" {
  name = "page_extractor_lambda_role"

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

resource "aws_iam_role_policy_attachment" "page_extractor_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.page_extractor.name
}
