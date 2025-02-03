# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "oai" {
  provider = aws.virginia
  comment  = "OAI for pdf2docx.vizeet.me"
}

# CloudFront Distribution
#resource "aws_cloudfront_distribution" "website" {
#  provider = aws.virginia
#  origin {
#    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
#    origin_id   = "S3-Origin"
#
#    s3_origin_config {
#      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
#    }
#  }
#
#  origin {
#    domain_name = replace(aws_apigatewayv2_api.presigned_url_api.api_endpoint, "/^https?:///", "")
#    origin_id   = "API-Gateway"
#
#    custom_origin_config {
#      http_port              = 80
#      https_port             = 443
#      origin_protocol_policy = "https-only"
#      origin_ssl_protocols   = ["TLSv1.2"]
#    }
#  }
#
#  enabled             = true
#  is_ipv6_enabled     = true
#  default_root_object = "index.html"
#  aliases             = ["pdf2docx.vizeet.me"]
#
#  default_cache_behavior {
#    allowed_methods  = ["GET", "HEAD", "OPTIONS"]  # Use this for static websites
#    cached_methods   = ["GET", "HEAD"]
#    target_origin_id = "S3-Origin"
#  
#    forwarded_values {
#      query_string = true
#      cookies {
#        forward = "none"
#      }
#    }
#  
#    viewer_protocol_policy = "redirect-to-https"
#    min_ttl                = 0
#    default_ttl            = 3600
#    max_ttl                = 86400
#  }
#
#  ordered_cache_behavior {
#    path_pattern     = "/api/*"
#    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
#    cached_methods   = ["GET", "HEAD"]
#    target_origin_id = "API-Gateway"
#
#    forwarded_values {
#      query_string = true
#      headers      = ["Origin", "Authorization"]
#      cookies {
#        forward = "none"
#      }
#    }
#
#    viewer_protocol_policy = "redirect-to-https"
#    min_ttl                = 0
#    default_ttl            = 0
#    max_ttl                = 0
#  }
#
#  restrictions {
#    geo_restriction {
#      restriction_type = "none"
#    }
#  }
#
#  viewer_certificate {
#    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
#    ssl_support_method       = "sni-only"
#    minimum_protocol_version = "TLSv1.2_2021"
#  }
#}

#resource "aws_cloudfront_cache_invalidation" "assets" {
#  distribution_id = aws_cloudfront_distribution.website.id
#  paths = ["/*"]
#}

resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-Origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = replace(aws_apigatewayv2_api.presigned_url_api.api_endpoint, "/^https?:///", "")
    origin_id   = "API-Gateway"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = ["pdf2docx.vizeet.me"]

  # Default cache behavior for static content
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    #default_ttl            = 3600
    #max_ttl                = 86400
  }

  # API cache behavior
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    #allowed_methods  = ["GET", "HEAD", "OPTIONS", "POST"]
    allowed_methods  = ["HEAD", "GET", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "API-Gateway"

    forwarded_values {
      query_string = true
      headers      = ["Origin", "Authorization"]
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

#resource "aws_cloudfront_cache_invalidation" "api_cache_invalidation" {
#  distribution_id = aws_cloudfront_distribution.website.id
#
#  paths {
#    items = ["/api/*", "/generate-url"]
#    quantity = 2
#  }
#}
