########################################################################################################################
# DNS and TLS certificate
#
# Same approach as tfe_fdo_aws_podman_active-active: a Let's Encrypt certificate is requested with the ACME DNS-01
# challenge in a Route53 hosted zone, and Route53 holds the DNS name of the TFE site. The load balancer only forwards
# TCP, so the certificate lives on the TFE nodes and TFE terminates TLS itself.
########################################################################################################################

data "aws_route53_zone" "base_domain" {
  name = var.dns_zonename
}

resource "tls_private_key" "acme_account" {
  algorithm = "RSA"
}

resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.acme_account.private_key_pem
  email_address   = var.certificate_email
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.registration.account_key_pem
  common_name     = local.tfe_fqdn

  recursive_nameservers        = ["1.1.1.1:53"]
  disable_complete_propagation = true

  dns_challenge {
    provider = "route53"

    # The ACME provider runs its own AWS client (not the aws provider), so it needs the region explicitly.
    config = {
      AWS_HOSTED_ZONE_ID = data.aws_route53_zone.base_domain.zone_id
      AWS_REGION         = var.aws_region
    }
  }

  depends_on = [acme_registration.registration]
}

# The public name of the load balancer is not fixed, so the site name is a CNAME to it.
resource "aws_route53_record" "tfe" {
  zone_id = data.aws_route53_zone.base_domain.zone_id
  name    = var.dns_hostname
  type    = "CNAME"
  ttl     = "300"
  records = [ibm_is_lb.tfe.hostname]
}

resource "aws_route53_record" "client" {
  count = var.create_client ? 1 : 0

  zone_id = data.aws_route53_zone.base_domain.zone_id
  name    = "${var.dns_hostname}-client"
  type    = "A"
  ttl     = "300"
  records = [ibm_is_floating_ip.client[0].address]
}
