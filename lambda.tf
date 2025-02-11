# Lambda Function
resource "aws_lambda_function" "sqs_trigger_lambda" {
  function_name = "sqs-trigger-lambda"
  role          = aws_iam_role.lambda_role.arn
  timeout       = 150
  memory_size   = 128

  # Use the ECR image as the deployment package
  image_uri    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/sqs-lambda-trigger:latest"
  package_type = "Image" # Specify that the deployment package is a container image

  environment {
    variables = {
      ECS_CLUSTER         = aws_ecs_cluster.pdf_cluster.name
      ECS_TASK_DEFINITION = aws_ecs_task_definition.pdf_task.family
      SQS_QUEUE_URL       = aws_sqs_queue.pdf_queue.id
      DLQ_QUEUE_URL       = aws_sqs_queue.dlq.id
      #SUBNET_IDS          = jsonencode(local.lambda_subnet_ids)
      SUBNET_IDS = jsonencode(aws_subnet.private_subnet[*].id)
    }
  }

  # Configure the Lambda function to run in the same VPC as the ECS cluster
  vpc_config {
    subnet_ids         = aws_subnet.private_subnet[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # Ensure the Lambda function has permissions to write logs to the Log Group
  depends_on = [aws_cloudwatch_log_group.lambda_log_group]
}

# Lambda Event Source Mapping (Trigger by SQS)
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.pdf_queue.arn
  function_name    = aws_lambda_function.sqs_trigger_lambda.arn
  batch_size       = 10 # Process up to 10 messages at a time
}

# Lambda Function
resource "aws_lambda_function" "presigned_url" {
  function_name = "generate-presigned-url"
  role          = aws_iam_role.lambda_exec.arn
  image_uri    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/gen_presigned_url:latest"
  package_type = "Image" # Specify that the deployment package is a container image

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.website.bucket
    }
  }
  reserved_concurrent_executions = 100 # Adjust as needed
  timeout = 300
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_url.function_name
  principal     = "apigateway.amazonaws.com"
}
