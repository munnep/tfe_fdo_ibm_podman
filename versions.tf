terraform {
  required_version = ">= 1.3.0"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = ">= 1.71.0, < 2.0.0"
    }
    # DNS (Route53) and the Let's Encrypt certificate are handled on AWS, like tfe_fdo_aws_podman_active-active
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.5"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}
