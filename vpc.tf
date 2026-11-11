########################################################################################################################
# VPC (Virtual Private Cloud), Address Prefixes, Public Gateways, Subnets and Network ACL
#
# One subnet (with its own public gateway) is created per zone: 10.10.10.0/24 in <region>-1, 10.10.20.0/24 in
# <region>-2 and so on. The TFE nodes, the load balancer and the VPE gateways all use these subnets.
########################################################################################################################

resource "ibm_is_vpc" "vpc" {
  name                      = "${var.environment_prefix}-vpc"
  resource_group            = local.resource_group_id
  address_prefix_management = "manual"
  no_sg_acl_rules           = true
  tags                      = var.resource_tags
}

locals {
  zones = {
    for i in range(var.zone_count) : "${var.region}-${i + 1}" => {
      index = i + 1
      cidr  = cidrsubnet("10.10.0.0/16", 8, (i + 1) * 10)
    }
  }
  primary_zone = "${var.region}-1"
}

resource "ibm_is_vpc_address_prefix" "address_prefix" {
  for_each = local.zones

  name       = "${var.environment_prefix}-vpc-zone-${each.value.index}-1"
  zone       = each.key
  vpc        = ibm_is_vpc.vpc.id
  cidr       = each.value.cidr
  is_default = false
}

resource "ibm_is_public_gateway" "gateway" {
  for_each = local.zones

  name           = "${var.environment_prefix}-vpc-public-gateway-zone-${each.value.index}"
  vpc            = ibm_is_vpc.vpc.id
  zone           = each.key
  resource_group = local.resource_group_id
  tags           = var.resource_tags
}

########################################################################################################################
# Network ACL rules
########################################################################################################################

resource "ibm_is_network_acl" "network_acl" {
  name           = "vpc-acl"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = local.resource_group_id

  rules {
    name            = "allow-all-inbound"
    action          = "allow"
    direction       = "inbound"
    source          = "0.0.0.0/0"
    destination     = "0.0.0.0/0"
    protocol        = "tcp"
    port_min        = 1
    port_max        = 65535
    source_port_min = 1
    source_port_max = 65535
  }

  rules {
    name            = "allow-all-outbound"
    action          = "allow"
    direction       = "outbound"
    source          = "0.0.0.0/0"
    destination     = "0.0.0.0/0"
    protocol        = "tcp"
    port_min        = 1
    port_max        = 65535
    source_port_min = 1
    source_port_max = 65535
  }

  rules {
    name            = "allow-all-udp-inbound"
    action          = "allow"
    direction       = "inbound"
    source          = "0.0.0.0/0"
    destination     = "0.0.0.0/0"
    protocol        = "udp"
    port_min        = 1
    port_max        = 65535
    source_port_min = 1
    source_port_max = 65535
  }

  rules {
    name            = "allow-all-udp-outbound"
    action          = "allow"
    direction       = "outbound"
    source          = "0.0.0.0/0"
    destination     = "0.0.0.0/0"
    protocol        = "udp"
    port_min        = 1
    port_max        = 65535
    source_port_min = 1
    source_port_max = 65535
  }
}

resource "ibm_is_subnet" "subnet" {
  for_each = local.zones

  name            = "${var.environment_prefix}-vpc-zone-${each.value.index}"
  vpc             = ibm_is_vpc.vpc.id
  zone            = each.key
  resource_group  = local.resource_group_id
  ipv4_cidr_block = each.value.cidr
  network_acl     = ibm_is_network_acl.network_acl.id
  public_gateway  = ibm_is_public_gateway.gateway[each.key].id
  tags            = var.resource_tags

  depends_on = [ibm_is_vpc_address_prefix.address_prefix]
}

########################################################################################################################
# Virtual Private Endpoints (VPE) and Security Group
#
# Private connectivity from the TFE nodes to IBM Cloud Databases (PostgreSQL and Redis). A VPE gateway gets one
# reserved IP in every zone, so the databases stay reachable if a zone is unavailable.
########################################################################################################################

resource "ibm_is_security_group" "vpe" {
  name           = "${var.environment_prefix}-vpc-vpe-sg"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = local.resource_group_id
  tags           = var.resource_tags
}

# Only the TFE nodes may talk to the databases.
resource "ibm_is_security_group_rule" "vpe_postgres_inbound" {
  group     = ibm_is_security_group.vpe.id
  direction = "inbound"
  remote    = ibm_is_security_group.tfe_node.id
  protocol  = "tcp"
  port_min  = local.postgres_port
  port_max  = local.postgres_port
}

resource "ibm_is_security_group_rule" "vpe_redis_inbound" {
  group     = ibm_is_security_group.vpe.id
  direction = "inbound"
  remote    = ibm_is_security_group.tfe_node.id
  protocol  = "tcp"
  port_min  = local.redis_port
  port_max  = local.redis_port
}

resource "ibm_is_security_group_rule" "vpe_outbound" {
  group     = ibm_is_security_group.vpe.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

# ibm_database returns before the instance is registered as a VPE target, which fails with "Could not find service".
resource "time_sleep" "wait_for_databases" {
  create_duration = "180s"

  depends_on = [
    ibm_database.postgres,
    ibm_database.redis,
    ibm_resource_key.postgres_service_credentials,
    ibm_resource_key.redis_service_credentials,
  ]
}

resource "ibm_is_virtual_endpoint_gateway" "postgres" {
  name            = "${var.environment_prefix}-postgres-vpe"
  vpc             = ibm_is_vpc.vpc.id
  resource_group  = local.resource_group_id
  security_groups = [ibm_is_security_group.vpe.id]

  target {
    crn           = local.postgres_crn
    resource_type = "provider_cloud_service"
  }

  dynamic "ips" {
    for_each = local.zones
    content {
      subnet = ibm_is_subnet.subnet[ips.key].id
      name   = "${var.environment_prefix}-postgres-vpe-ip-zone-${ips.value.index}"
    }
  }

  tags       = var.resource_tags
  depends_on = [time_sleep.wait_for_databases]
}

resource "ibm_is_virtual_endpoint_gateway" "redis" {
  name            = "${var.environment_prefix}-redis-vpe"
  vpc             = ibm_is_vpc.vpc.id
  resource_group  = local.resource_group_id
  security_groups = [ibm_is_security_group.vpe.id]

  target {
    crn           = local.redis_crn
    resource_type = "provider_cloud_service"
  }

  dynamic "ips" {
    for_each = local.zones
    content {
      subnet = ibm_is_subnet.subnet[ips.key].id
      name   = "${var.environment_prefix}-redis-vpe-ip-zone-${ips.value.index}"
    }
  }

  tags       = var.resource_tags
  depends_on = [time_sleep.wait_for_databases]
}
