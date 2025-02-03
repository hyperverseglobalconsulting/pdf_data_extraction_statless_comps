# Create a custom VPC
resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "pdf2docx-vpc"
  }
}

# Create private subnets
resource "aws_subnet" "private_subnet" {
  count             = 2
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.${count.index + 2}.0/24" # Adjust CIDR blocks
  availability_zone = ["us-east-2a", "us-east-2b"][count.index]

  tags = {
    Name = "pdf2docx-private-subnet-${count.index + 1}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id   = aws_vpc.custom_vpc.id

  tags = {
    Name = "pdf2docx-igw"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "private_route_table" {
  vpc_id   = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "pdf2docx-public-route-table"
  }
}

# Associate the public subnet with the route table
resource "aws_route_table_association" "private_subnet_association" {
  count          = length(aws_subnet.private_subnet)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}
