########################################################################################################################
# TFE nodes: RHEL + Podman in an instance group behind the load balancer
#
# Start with tfe_node_count = 1 (the default). When TFE is healthy, set tfe_node_count = 2 (or more) and apply again:
# the instance group only adds members, the template (and so the running node) is not touched.
########################################################################################################################

resource "ibm_is_ssh_key" "tfe" {
  name           = "${var.environment_prefix}-key"
  public_key     = var.ssh_public_key
  resource_group = local.resource_group_id
  tags           = var.resource_tags
}

data "ibm_is_image" "rhel" {
  name = var.tfe_image_name
}

resource "ibm_is_instance_template" "tfe" {
  # Template names are unique and a template cannot be changed, so the name carries a hash of the user data.
  name           = "${var.environment_prefix}-tfe-${substr(sha1(local.tfe_user_data), 0, 8)}"
  image          = data.ibm_is_image.rhel.id
  profile        = var.tfe_instance_profile
  vpc            = ibm_is_vpc.vpc.id
  zone           = local.primary_zone
  keys           = [ibm_is_ssh_key.tfe.id]
  resource_group = local.resource_group_id
  user_data      = local.tfe_user_data

  primary_network_interface {
    subnet          = ibm_is_subnet.subnet[local.primary_zone].id
    security_groups = [ibm_is_security_group.tfe_node.id]
  }

  boot_volume {
    size = var.tfe_boot_volume_gb
  }

  volume_attachments {
    name                             = "${var.environment_prefix}-tfe-data"
    delete_volume_on_instance_delete = true

    volume_prototype {
      capacity = var.tfe_data_volume_gb
      profile  = "general-purpose"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "ibm_is_instance_group" "tfe" {
  name              = "${var.environment_prefix}-tfe-group"
  instance_template = ibm_is_instance_template.tfe.id
  instance_count    = var.tfe_node_count
  subnets           = [for s in ibm_is_subnet.subnet : s.id]
  resource_group    = local.resource_group_id
  tags              = var.resource_tags

  load_balancer      = ibm_is_lb.tfe.id
  load_balancer_pool = ibm_is_lb_pool.tfe.pool_id
  application_port   = 443

  # The nodes need the databases and the certificate before they boot. Nothing in the user data points at the VPEs,
  # so the ordering has to be explicit (it used to come from the cluster worker pool).
  depends_on = [
    ibm_is_virtual_endpoint_gateway.postgres,
    ibm_is_virtual_endpoint_gateway.redis,
    ibm_is_lb_listener.https,
    aws_route53_record.tfe,
  ]
}
