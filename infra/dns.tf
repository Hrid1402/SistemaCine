//ACM en us-east-1
resource "aws_acm_certificate" "cert" {
  provider          = aws.dr
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

//Zona host en Route 53
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

//Health Check Route 53
resource "aws_route53_health_check" "cloudfront_health_check" {
  fqdn              = aws_cloudfront_distribution.cine_cdn.domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/cartelera"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "cine-cloudfront_health_check"
  }
}

//Registro Alias en Route 53 a Cloudfront
resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cine_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cine_cdn.hosted_zone_id
    evaluate_target_health = true
  }
}