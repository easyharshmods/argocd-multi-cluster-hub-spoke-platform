# Sync the hosted zone's nameservers to the domain registration (Route53 Domains, same account).
# This ensures the domain delegates to your Route53 hosted zone so ACM validation and DNS work.
# Only created when domain_registered_in_route53_domains = true and we have nameservers
# (from zone lookup or route53_name_servers variable).
resource "aws_route53domains_registered_domain" "main" {
  count       = var.domain_registered_in_route53_domains && length(local.route53_name_servers) > 0 ? 1 : 0
  provider    = aws.us_east_1
  domain_name = var.domain_name

  dynamic "name_server" {
    for_each = local.route53_name_servers
    content {
      name = name_server.value
    }
  }

  # Avoid changing contact/privacy; only manage nameservers
  lifecycle {
    ignore_changes = [
      admin_contact,
      billing_contact,
      registrant_contact,
      tech_contact,
      admin_privacy,
      billing_privacy,
      registrant_privacy,
      tech_privacy,
      auto_renew,
      transfer_lock,
      tags,
    ]
  }
}
