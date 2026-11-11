########################################################################################################################
# Security groups
#
#   lb        - the public load balancer: 443 from the internet
#   tfe_node  - the TFE nodes: 443 from the load balancer, 8201 (Vault, node to node) from each other, 22 from the client
#   client    - the optional client VM: 22 from var.client_ssh_cidr
#   vpe       - defined in vpc.tf, only accepts the database ports from tfe_node
########################################################################################################################

resource "ibm_is_security_group" "lb" {
  name           = "${var.environment_prefix}-lb-sg"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = local.resource_group_id
  tags           = var.resource_tags
}

resource "ibm_is_security_group_rule" "lb_https_inbound" {
  group     = ibm_is_security_group.lb.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  protocol  = "tcp"
  port_min  = 443
  port_max  = 443
}

resource "ibm_is_security_group_rule" "lb_to_nodes" {
  group     = ibm_is_security_group.lb.id
  direction = "outbound"
  remote    = ibm_is_security_group.tfe_node.id
  protocol  = "tcp"
  port_min  = 443
  port_max  = 443
}

resource "ibm_is_security_group" "tfe_node" {
  name           = "${var.environment_prefix}-tfe-node-sg"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = local.resource_group_id
  tags           = var.resource_tags
}

resource "ibm_is_security_group_rule" "node_https_from_lb" {
  group     = ibm_is_security_group.tfe_node.id
  direction = "inbound"
  remote    = ibm_is_security_group.lb.id
  protocol  = "tcp"
  port_min  = 443
  port_max  = 443
}

# Vault (internal TFE cluster traffic) between the nodes
resource "ibm_is_security_group_rule" "node_vault_from_nodes" {
  group     = ibm_is_security_group.tfe_node.id
  direction = "inbound"
  remote    = ibm_is_security_group.tfe_node.id
  protocol  = "tcp"
  port_min  = 8201
  port_max  = 8201
}

# Outbound: databases through the VPEs, COS, the image registry, package repositories
resource "ibm_is_security_group_rule" "node_outbound" {
  group     = ibm_is_security_group.tfe_node.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

resource "ibm_is_security_group" "client" {
  count = var.create_client ? 1 : 0

  name           = "${var.environment_prefix}-client-sg"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = local.resource_group_id
  tags           = var.resource_tags
}

resource "ibm_is_security_group_rule" "client_ssh_inbound" {
  count = var.create_client ? 1 : 0

  group     = ibm_is_security_group.client[0].id
  direction = "inbound"
  remote    = var.client_ssh_cidr
  protocol  = "tcp"
  port_min  = 22
  port_max  = 22
}

resource "ibm_is_security_group_rule" "client_outbound" {
  count = var.create_client ? 1 : 0

  group     = ibm_is_security_group.client[0].id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

resource "ibm_is_security_group_rule" "node_ssh_from_client" {
  count = var.create_client ? 1 : 0

  group     = ibm_is_security_group.tfe_node.id
  direction = "inbound"
  remote    = ibm_is_security_group.client[0].id
  protocol  = "tcp"
  port_min  = 22
  port_max  = 22
}
