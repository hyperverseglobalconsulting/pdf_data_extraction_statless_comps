# API Gateway to Trigger Lambda
#resource "aws_apigatewayv2_api" "presigned_url_api" {
#  name          = "presigned-url-api"
#  protocol_type = "HTTP"
#}

#resource "aws_apigatewayv2_api" "presigned_url_api" {
#  name          = "presigned-url-api"
#  protocol_type = "HTTP"
#
#  cors_configuration {
#    allow_methods = ["OPTIONS", "GET", "POST"]
#    allow_origins = ["*"]
#    allow_headers = ["*"]
#  }
#}

resource "aws_apigatewayv2_api" "presigned_url_api" {
  name          = "presigned-url-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_methods = ["POST", "OPTIONS"]
    allow_origins = ["https://pdf2docx.vizeet.me"]
    allow_headers = ["Content-Type"]
    expose_headers = ["*"]
    allow_credentials = true
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.presigned_url_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.presigned_url.invoke_arn
}

resource "aws_apigatewayv2_route" "post" {
  api_id    = aws_apigatewayv2_api.presigned_url_api.id
  route_key = "POST /generate-url"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = "pdf2docx.vizeet.me"
  domain_name_configuration {
    certificate_arn = aws_acm_certificate.api_cert_us_east_2.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

## Add OPTIONS route for CORS preflight requests
#resource "aws_apigatewayv2_route" "options" {
#  api_id    = aws_apigatewayv2_api.presigned_url_api.id
#  route_key = "OPTIONS /generate-url"
#  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
#}

resource "aws_apigatewayv2_deployment" "deployment" {
  api_id = aws_apigatewayv2_api.presigned_url_api.id
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.presigned_url_api.id
  name        = "prod"
  auto_deploy = true

  # Enable CloudWatch logs
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format          = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  # Enable execution logging
  default_route_settings {
    logging_level = "INFO" # Options: "OFF", "ERROR", "INFO"
    data_trace_enabled = true
    throttling_burst_limit = 10   # Increase if needed
    throttling_rate_limit  = 10   # Increase if needed
  }
}

## Add CORS headers to the OPTIONS route
#resource "aws_apigatewayv2_integration_response" "cors" {
#  api_id                   = aws_apigatewayv2_api.presigned_url_api.id
#  integration_id           = aws_apigatewayv2_integration.lambda.id
#  integration_response_key = "/generate-url/OPTIONS/200"
#
#  response_templates = {
#    "application/json" = ""
#  }
#}

#resource "aws_apigatewayv2_route_response" "cors" {
#  api_id             = aws_apigatewayv2_api.presigned_url_api.id
#  route_id           = aws_apigatewayv2_route.options.id
#  route_response_key = "$default"
#}

output "api_gateway_id" {
  value = aws_apigatewayv2_api.presigned_url_api.id
}
