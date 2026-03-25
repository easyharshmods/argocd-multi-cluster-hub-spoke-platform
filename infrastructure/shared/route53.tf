# When route53_zone_id is empty, create a public hosted zone for domain_name.
# ACM, cert validation records, and External DNS will use this zone.
# After apply, copy the zone's nameservers (output or Route53 console) to your domain registrar.
resource "aws_route53_zone" "main" {
  count   = var.route53_zone_id != "" ? 0 : 1
  name    = var.domain_name
  comment = "Managed by Terraform (infrastructure/shared)"

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.domain_name}" })
}

# DNS records for dagster and grafana subdomains are managed by External DNS
# (platform/core). No placeholder A records here — External DNS creates them from Ingress.
