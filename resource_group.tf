########################################################################################################################
# Resource Group
########################################################################################################################

resource "ibm_resource_group" "this" {
  name = "${var.environment_prefix}-rg"
  tags = var.resource_tags
}

locals {
  resource_group_id = ibm_resource_group.this.id
}
