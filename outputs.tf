########################################################################################################################
# Outputs
########################################################################################################################

# COS (Cloud Object Storage)
# output "cos_bucket_name" {
#   description = "COS bucket name."
#   value       = ibm_cos_bucket.tfe.bucket_name
# }

# output "cos_hmac_access_key_id" {
#   description = "COS HMAC access key ID for S3 API access."
#   value       = nonsensitive(ibm_resource_key.cos.credentials["cos_hmac_keys.access_key_id"])
# }

# output "cos_hmac_secret_access_key" {
#   description = "COS HMAC secret access key for S3 API access."
#   value       = nonsensitive(ibm_resource_key.cos.credentials["cos_hmac_keys.secret_access_key"])
# }

# output "cos_s3_endpoint_public" {
#   description = "COS S3 public endpoint."
#   value       = ibm_cos_bucket.tfe.s3_endpoint_public
# }

# output "region" {
#   description = "IBM Cloud region used for the COS bucket."
#   value       = var.region
# }

# PostgreSQL (IBM Cloud Databases)
# output "postgres_hostname" {
#   description = "PostgreSQL hostname."
#   value       = local.postgres_hostname
# }

# output "postgres_port" {
#   description = "PostgreSQL port."
#   value       = local.postgres_port
# }

# output "postgres_tfe_username" {
#   description = "PostgreSQL TFE username."
#   value       = nonsensitive(local.postgres_username)
# }

# output "postgres_tfe_password" {
#   description = "PostgreSQL TFE password."
#   value       = nonsensitive(local.postgres_password)
# }

# # Redis (IBM Cloud Databases)
# output "redis_hostname" {
#   description = "Redis hostname."
#   value       = local.redis_host
# }

# output "redis_port" {
#   description = "Redis port."
#   value       = local.redis_port
# }

# output "redis_username" {
#   description = "Redis TFE username."
#   value       = nonsensitive(local.redis_username)
# }

# output "redis_password_base64" {
#   description = "Redis TFE password (plain text despite the name, as returned by IBM Cloud Databases)."
#   value       = nonsensitive(local.redis_pass_base64)
# }

# output "redis_certificate_base64" {
#   description = "Redis certificate in base64 format."
#   value       = nonsensitive(local.redis_certificate_b64)
# }

# Terraform Enterprise
output "tfe_application" {
  description = "URL of Terraform Enterprise."
  value       = "https://${local.tfe_fqdn}"
}

output "load_balancer_hostname" {
  description = "Public name of the load balancer. The DNS name of TFE is a CNAME to this."
  value       = ibm_is_lb.tfe.hostname
}

output "tfe_node_count" {
  description = "Number of TFE nodes the instance group is asked to run."
  value       = ibm_is_instance_group.tfe.instance_count
}

# output "instance_group_id" {
#   description = "Instance group that holds the TFE nodes (ibmcloud is instance-group-memberships <id> lists the nodes)."
#   value       = ibm_is_instance_group.tfe.id
# }

output "client_ssh" {
  description = "SSH command for the client VM (jump host)."
  value       = var.create_client ? "ssh -i <private key> ubuntu@${ibm_is_floating_ip.client[0].address}" : null
}

# Private IPs of the TFE nodes, read from the instance group (refresh with "terraform apply -refresh-only" after scaling).
data "ibm_is_instances" "tfe_nodes" {
  instance_group = ibm_is_instance_group.tfe.id
  depends_on     = [ibm_is_instance_group.tfe]
}

output "tfe_node_private_ips" {
  description = "Private IP addresses of the TFE nodes."
  value       = [for i in data.ibm_is_instances.tfe_nodes.instances : i.primary_network_interface[0].primary_ip[0].address]
}

output "tfe_node_ssh" {
  description = "SSH commands for the TFE nodes, through the client VM as jump host. The stock IBM Cloud RHEL image logs in as vpcuser (use sudo for root)."
  value = var.create_client ? [
    for i in data.ibm_is_instances.tfe_nodes.instances :
    "ssh -J ubuntu@${ibm_is_floating_ip.client[0].address} vpcuser@${i.primary_network_interface[0].primary_ip[0].address}"
  ] : null
}

output "configure_tfe_command" {
  description = "Run this once, when https://<site>/api/v1/health/readiness works, to create the admin user and the organization \"test\"."
  value       = "./scripts/configure_tfe.sh ${local.tfe_fqdn} ${var.certificate_email} admin '<choose an admin password>'"
}
