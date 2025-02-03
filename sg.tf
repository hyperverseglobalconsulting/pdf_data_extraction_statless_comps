# Security Group for ECS Tasks
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-security-group"
  description = "Allow all traffic for ECS tasks"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Lambda Function
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-security-group"
  description = "Allow all traffic for Lambda function"
  vpc_id      = aws_vpc.custom_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for the VPC Endpoint
resource "aws_security_group" "vpce_sg" {
  name        = "vpce-ecs-sg"
  description = "Security group for ECS VPC Endpoint"
  vpc_id      = aws_vpc.custom_vpc.id

  # Allow inbound HTTPS (port 443) from resources in the VPC
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.custom_vpc.cidr_block]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pdf2docx-vpce-ecs-sg"
  }
}
