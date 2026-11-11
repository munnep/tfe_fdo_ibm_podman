########################################################################################################################
# Public application load balancer
#
# TCP passthrough on 443: TLS is terminated by TFE on the nodes with the Let's Encrypt certificate. The nodes are
# registered in the pool by the instance group (compute.tf), so there are no ibm_is_lb_pool_member resources.
########################################################################################################################

resource "ibm_is_lb" "tfe" {
  name            = "${var.environment_prefix}-tfe-lb"
  type            = "public"
  subnets         = [for s in ibm_is_subnet.subnet : s.id]
  security_groups = [ibm_is_security_group.lb.id]
  resource_group  = local.resource_group_id
  tags            = var.resource_tags
}

resource "ibm_is_lb_pool" "tfe" {
  name                = "${var.environment_prefix}-tfe-pool"
  lb                  = ibm_is_lb.tfe.id
  algorithm           = "round_robin"
  protocol            = "tcp"
  health_type         = "https"
  health_monitor_url  = "/api/v1/health/readiness"
  health_monitor_port = 443
  health_delay        = 15
  health_retries      = 3
  health_timeout      = 10
}

resource "ibm_is_lb_listener" "https" {
  lb                      = ibm_is_lb.tfe.id
  protocol                = "tcp"
  port                    = 443
  default_pool            = ibm_is_lb_pool.tfe.pool_id
  idle_connection_timeout = 3600
}
