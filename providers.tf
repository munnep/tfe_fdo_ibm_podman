provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
  visibility       = var.ibmcloud_provider_visibility
}

# Only used for Route53 (DNS records and the DNS-01 challenge). Credentials come from the usual AWS environment
# variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, ...) or a profile.
provider "aws" {
  region = var.aws_region
}

provider "acme" {
  server_url = var.letsencrypt_environment == "production" ? "https://acme-v02.api.letsencrypt.org/directory" : "https://acme-staging-v02.api.letsencrypt.org/directory"
}
