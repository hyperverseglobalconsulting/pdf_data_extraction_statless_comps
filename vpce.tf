# VPC Endpoint for ECS
resource "aws_vpc_endpoint" "ecs_vpce" {
  vpc_id             = aws_vpc.custom_vpc.id
  service_name       = "com.amazonaws.us-east-2.ecs" # Replace with your region
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [aws_subnet.public_subnet.id]
  security_group_ids = [aws_security_group.vpce_sg.id]

  # Enable DNS resolution for the endpoint
  private_dns_enabled = true

  tags = {
    Name = "ecs-vpce"
  }
}
