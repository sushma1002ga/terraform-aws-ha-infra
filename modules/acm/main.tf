################################################################################
# ACM Module — SSL/TLS Certificates with DNS Validation
################################################################################

# ─── Primary Region Certificate (for ALB) ────────────────────────────────────

resource "aws_acm_certificate" "primary" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-primary-cert"
  }
}

# DNS Validation Records
resource "aws_route53_record" "primary_validation" {

  for_each = {
    for dvo in aws_acm_certificate.primary.domain_validation_options :
    dvo.domain_name => dvo
  }

  allow_overwrite = true

  name = each.value.resource_record_name

  records = [
    each.value.resource_record_value
  ]

  ttl = 60

  type = each.value.resource_record_type

  zone_id = var.zone_id
}

resource "aws_acm_certificate_validation" "primary" {
  certificate_arn         = aws_acm_certificate.primary.arn
  validation_record_fqdns = [for record in aws_route53_record.primary_validation : record.fqdn]
}

# ─── CloudFront Certificate (must be in us-east-1) ──────────────────────────

resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-cloudfront-cert"
  }
}

resource "aws_route53_record" "cloudfront_validation" {

  provider = aws.us_east_1

  for_each = {
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options :
    dvo.domain_name => dvo
  }


  allow_overwrite = true

  name = each.value.resource_record_name

  records = [
    each.value.resource_record_value
  ]

  ttl = 60

  type = each.value.resource_record_type

  zone_id = var.zone_id
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cloudfront_validation : record.fqdn]
}
