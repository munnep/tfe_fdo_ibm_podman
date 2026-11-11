########################################################################################################################
# COS (Cloud Object Storage): instance, bucket and HMAC credentials
########################################################################################################################

resource "ibm_resource_instance" "cos" {
  name              = "${var.environment_prefix}-cos"
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
  resource_group_id = local.resource_group_id
  tags              = var.resource_tags
}

resource "ibm_cos_bucket" "tfe" {
  # Bucket names are globally unique: suffix with part of the instance GUID.
  bucket_name          = "${var.environment_prefix}-cos-bucket-${substr(ibm_resource_instance.cos.guid, 0, 8)}"
  resource_instance_id = ibm_resource_instance.cos.id
  region_location      = var.region
  storage_class        = "standard"
}

resource "ibm_resource_key" "cos" {
  name                 = "${var.environment_prefix}-cos-credentials"
  role                 = "Writer"
  resource_instance_id = ibm_resource_instance.cos.id
  parameters           = { HMAC = true }
}
