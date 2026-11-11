########################################################################################################################
# Optional client VM (jump host with the Terraform CLI), like instance_client.tf in the AWS example
########################################################################################################################

data "ibm_is_image" "client" {
  count = var.create_client ? 1 : 0
  name  = var.client_image_name
}

resource "ibm_is_instance" "client" {
  count = var.create_client ? 1 : 0

  name           = "${var.environment_prefix}-client"
  image          = data.ibm_is_image.client[0].id
  profile        = "bx2-2x8"
  vpc            = ibm_is_vpc.vpc.id
  zone           = local.primary_zone
  keys           = [ibm_is_ssh_key.tfe.id]
  resource_group = local.resource_group_id
  user_data      = local.client_user_data
  tags           = var.resource_tags

  primary_network_interface {
    subnet          = ibm_is_subnet.subnet[local.primary_zone].id
    security_groups = [ibm_is_security_group.client[0].id]
  }
}

resource "ibm_is_floating_ip" "client" {
  count = var.create_client ? 1 : 0

  name           = "${var.environment_prefix}-client-fip"
  target         = ibm_is_instance.client[0].primary_network_interface[0].id
  resource_group = local.resource_group_id
  tags           = var.resource_tags
}
