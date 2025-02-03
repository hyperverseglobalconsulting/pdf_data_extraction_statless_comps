# Create certificate in us-east-2 for API Gateway
resource "aws_acm_certificate" "api_cert_us_east_2" {
  domain_name       = "pdf2docx.vizeet.me"
  validation_method = "DNS"

  tags = {
    Name = "api_cert_us_east_2"
  }
  lifecycle {
    create_before_destroy = true
  }
}

#resource "aws_acm_certificate_validation" "api_cert_validation_us_east_2" {
#  certificate_arn         = aws_acm_certificate.api_cert_us_east_2.arn
#  validation_record_fqdns = [aws_route53_record.api_cert_validation_us_east_2.fqdn]
#}

resource "aws_acm_certificate_validation" "api_cert_validation_us_east_2" {
  certificate_arn         = aws_acm_certificate.api_cert_us_east_2.arn
  validation_record_fqdns = [for record in aws_route53_record.api_cert_validation_us_east_2 : record.fqdn]
}

# ACM Certificate in us-east-1 (required for CloudFront)
resource "aws_acm_certificate" "cert" {
  provider          = aws.virginia
  domain_name       = "pdf2docx.vizeet.me"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ACM Certificate Validation
resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.virginia
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

