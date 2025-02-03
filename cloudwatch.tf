resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/sqs-trigger-lambda" # Log group name for the Lambda function
  retention_in_days = 1                                # Set retention to 1 day
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/pdf-task"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/presigned-url-api"
  retention_in_days = 1
}
