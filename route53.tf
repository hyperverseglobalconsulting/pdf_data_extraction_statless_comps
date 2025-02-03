# Get Route53 hosted zone information from main region
data "aws_route53_zone" "main" {
  name         = "vizeet.me."
  private_zone = false
}

# DNS Validation Records in main region Route53
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
  records         = [each.value.record]
  ttl             = 60
}

#resource "aws_route53_record" "api_cert_validation_us_east_2" {
#  name    = tolist(aws_acm_certificate.api_cert_us_east_2.domain_validation_options)[0].resource_record_name
#  type    = tolist(aws_acm_certificate.api_cert_us_east_2.domain_validation_options)[0].resource_record_type
#  zone_id         = data.aws_route53_zone.main.zone_id
#  records = [tolist(aws_acm_certificate.api_cert_us_east_2.domain_validation_options)[0].resource_record_value]
#  ttl     = 60
#}

# Validation records for API Gateway certificate
resource "aws_route53_record" "api_cert_validation_us_east_2" {
  for_each = {
    for dvo in aws_acm_certificate.api_cert_us_east_2.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
  records         = [each.value.record]
  ttl             = 60
}

# Route53 A Record for CloudFront
resource "aws_route53_record" "website" {
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = "pdf2docx.vizeet.me"
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}
