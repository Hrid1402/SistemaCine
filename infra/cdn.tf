# OAC
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "s3-oac-${var.environment}"
  description                       = "OAC para acceso seguro al bucket de posters"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Distribución Cloudfront
resource "aws_cloudfront_distribution" "cine_cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN SistemaCine - ${var.environment}"
  default_root_object = ""

  # Origen 1: S3
  origin {
    domain_name              = aws_s3_bucket.posters.bucket_regional_domain_name
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  # Origen 2: API Gateway
  origin {
    domain_name = replace(aws_apigatewayv2_api.cine_api.api_endpoint, "https://", "")
    origin_id   = "ApiGatewayOrigin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Comportamiento por Defecto API Gateway
  default_cache_behavior {
    target_origin_id       = "ApiGatewayOrigin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    # Deshabilitar caché
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }

  # Comportamiento ordenado para imágenes S3
  ordered_cache_behavior {
    path_pattern           = "/posters/*"
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}