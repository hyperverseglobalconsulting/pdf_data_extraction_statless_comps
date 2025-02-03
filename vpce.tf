# VPC Endpoint for ECS
resource "aws_vpc_endpoint" "ecs_vpce" {
  vpc_id             = aws_vpc.custom_vpc.id
  service_name       = "com.amazonaws.us-east-2.ecs" # Replace with your region
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.private_subnet[*].id
  security_group_ids = [aws_security_group.vpce_sg.id]

  # Enable DNS resolution for the endpoint
  private_dns_enabled = true

  tags = {
    Name = "pdf2docx-ecs-vpce"
  }
}

# Interface VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "cloudwatch_logs_vpce" {
  vpc_id              = aws_vpc.custom_vpc.id
  service_name        = "com.amazonaws.us-east-2.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_subnet[*].id
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "pdf2docx-cloudwatch-logs-vpce"
  }
}

# Interface VPC Endpoint for SQS
resource "aws_vpc_endpoint" "sqs_vpce" {
  vpc_id              = aws_vpc.custom_vpc.id
  service_name        = "com.amazonaws.us-east-2.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_subnet[*].id
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "pdf2docx-sqs-vpce"
  }
}

# Interface VPC Endpoint for ECR
resource "aws_vpc_endpoint" "ecr_vpce" {
  vpc_id              = aws_vpc.custom_vpc.id
  service_name        = "com.amazonaws.us-east-2.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_subnet[*].id
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "pdf2docx-ecr-vpce"
  }
}

# Gateway VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3_gateway_vpce" {
  vpc_id            = aws_vpc.custom_vpc.id
  service_name      = "com.amazonaws.us-east-2.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_route_table.id
  ]

  tags = {
    Name = "pdf2docx-s3-gateway-vpce"
  }
}

