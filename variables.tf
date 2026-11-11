########################################################################################################################
# Input Variables
########################################################################################################################

variable "environment_prefix" {
  type        = string
  description = "the naming convention for everything created"
}

variable "ibmcloud_api_key" {
  type        = string
  description = "IBM Cloud API key. Prefer setting env var IC_API_KEY instead of putting it in a file."
  sensitive   = true
  default     = null
}

variable "ibmcloud_provider_visibility" {
  type        = string
  description = "IBM Cloud provider visibility setting."
  default     = "public"
}

variable "region" {
  type        = string
  description = "Region where resources are created"
  default     = "eu-de"
}

variable "resource_tags" {
  type        = list(string)
  description = "Optional list of tags to be added to created resources"
  default     = []
}

variable "access_tags" {
  type        = list(string)
  description = "Optional list of access tags to be added to created resources"
  default     = []
}

########################################################################################################################
# PostgreSQL (IBM Cloud Databases)
########################################################################################################################

variable "postgres_deletion_protection" {
  type        = bool
  description = "Enable deletion protection within terraform."
  default     = false
}

variable "postgres_members" {
  type        = number
  description = "Number of members (nodes) for the PostgreSQL cluster. 2 = HA with 2 zones, 3 = HA with 3 zones (recommended for production)."
  default     = 2

}

########################################################################################################################
# Redis (IBM Cloud Databases)
########################################################################################################################

variable "redis_deletion_protection" {
  type        = bool
  description = "Enable deletion protection for Redis instance."
  default     = false
}

variable "redis_version" {
  type        = string
  description = "Redis version to deploy."
  default     = "8.2"
}

########################################################################################################################
# Network
########################################################################################################################

variable "zone_count" {
  type        = number
  description = "Number of availability zones to use (<region>-1, <region>-2, ...). Every zone gets a subnet, a public gateway and a VPE IP. TFE nodes are spread over the zones."
  default     = 2

  validation {
    condition     = var.zone_count >= 1 && var.zone_count <= 3
    error_message = "zone_count must be 1, 2 or 3."
  }
}

########################################################################################################################
# DNS and certificate (AWS Route53 + Let's Encrypt, same approach as tfe_fdo_aws_podman_active-active)
########################################################################################################################

variable "aws_region" {
  type        = string
  description = "AWS region for the AWS provider. Route53 is global, so this only has to be a valid region."
  default     = "eu-central-1"
}

variable "dns_hostname" {
  type        = string
  description = "Host name of the TFE site. The site is reachable on <dns_hostname>.<dns_zonename>."
}

variable "dns_zonename" {
  type        = string
  description = "Route53 hosted zone (domain) in which the DNS record and the DNS-01 challenge records are created."
}

variable "certificate_email" {
  type        = string
  description = "Email address the Let's Encrypt certificate is registered with."
}

variable "letsencrypt_environment" {
  type        = string
  description = "\"production\" gives a trusted certificate (limited to 5 per week for the same name). \"staging\" gives an untrusted certificate without those limits, use it only to test the flow."
  default     = "production"

  validation {
    condition     = contains(["production", "staging"], var.letsencrypt_environment)
    error_message = "letsencrypt_environment must be \"production\" or \"staging\"."
  }
}

########################################################################################################################
# Terraform Enterprise
########################################################################################################################

variable "tfe_license" {
  type        = string
  description = "Terraform Enterprise license (the raw license string)."
  sensitive   = true
}

variable "tfe_release" {
  type        = string
  description = "Terraform Enterprise image tag to install, for example v202502-2."
}

variable "tfe_image" {
  type        = string
  description = "Image repository without tag. Use cp.icr.io/cp/ibm-terraform/ibm-terraform for the IBM entitled registry."
  default     = "images.releases.hashicorp.com/hashicorp/terraform-enterprise"
}

variable "tfe_registry_username" {
  type        = string
  description = "User name for the image registry. \"terraform\" for the HashiCorp registry, \"cp\" for cp.icr.io."
  default     = "terraform"
}

variable "tfe_registry_password" {
  type        = string
  description = "Password for the image registry. Defaults to the TFE license, which is what the HashiCorp registry expects. Set it to the entitlement key for cp.icr.io."
  sensitive   = true
  default     = null
}

variable "tfe_encryption_password" {
  type        = string
  description = "TFE_ENCRYPTION_PASSWORD. Identical on every node. Changing it later makes existing encrypted data unreadable."
  sensitive   = true
}

variable "iact_subnets" {
  type        = string
  description = "TFE_IACT_SUBNETS, the networks allowed to retrieve the initial admin creation token. Behind the load balancer TFE does not see the real client address, so tighten this only when you use the client VM."
  default     = "0.0.0.0/0"
}

########################################################################################################################
# TFE hosts (RHEL + Podman)
########################################################################################################################

variable "tfe_node_count" {
  type        = number
  description = "Number of TFE nodes. Start with 1: TFE has to initialise the database once from a single node. When it is healthy, set this to 2 or more and apply again to scale out."
  default     = 1

  validation {
    condition     = var.tfe_node_count >= 0 && var.tfe_node_count <= 10
    error_message = "tfe_node_count must be between 0 and 10."
  }
}

variable "tfe_instance_profile" {
  type        = string
  description = "Profile (size) of the TFE nodes. Note the dash notation of VPC profiles, for example bx2-8x32."
  default     = "bx2-8x32"
}

variable "tfe_image_name" {
  type        = string
  description = "Name of the stock RHEL image for the TFE nodes (see 'ibmcloud is images --visibility public'). Pinned on purpose: a different image changes the instance template and replaces the instance group."
  default     = "ibm-redhat-9-6-minimal-amd64-15"
}

variable "tfe_boot_volume_gb" {
  type        = number
  description = "Size of the boot volume in GB."
  default     = 100
}

variable "tfe_data_volume_gb" {
  type        = number
  description = "Size of the data volume in GB. It is mounted on /var/lib/containers (container images, TFE cache and run data)."
  default     = 100
}

variable "tfe_swap_gb" {
  type        = number
  description = "Size of the swap file in GB."
  default     = 16
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key that is placed on all nodes and on the client VM."
}

variable "cos_endpoint_type" {
  type        = string
  description = "COS endpoint the nodes use for the S3 API: \"direct\" (VPC only), \"private\" or \"public\"."
  default     = "direct"

  validation {
    condition     = contains(["direct", "private", "public"], var.cos_endpoint_type)
    error_message = "cos_endpoint_type must be direct, private or public."
  }
}

variable "postgres_client_image" {
  type        = string
  description = "Image used to run psql only when the postgresql package cannot be installed on a node."
  default     = "docker.io/library/postgres:16"
}

variable "postgres_init_attempts" {
  type        = number
  description = "How often a node tries to create the PostgreSQL extensions before it gives up."
  default     = 30
}

variable "postgres_init_interval" {
  type        = number
  description = "Seconds between two attempts to create the PostgreSQL extensions."
  default     = 20
}

########################################################################################################################
# Client VM (optional jump host with the Terraform CLI)
########################################################################################################################

variable "create_client" {
  type        = bool
  description = "Create a small Ubuntu VM with a floating IP. Use it as SSH jump host to the TFE nodes and to run Terraform against TFE."
  default     = true
}

variable "client_ssh_cidr" {
  type        = string
  description = "Source network that may SSH to the client VM. Restrict this to your own address."
  default     = "0.0.0.0/0"
}

variable "client_image_name" {
  type        = string
  description = "Name of the stock Ubuntu image for the client VM."
  default     = "ibm-ubuntu-24-04-5-minimal-amd64-2"
}

variable "terraform_client_version" {
  type        = string
  description = "Terraform CLI version for the client VM (apt package version, for example 1.12.2-1). Empty installs the latest."
  default     = ""
}
