########################################################################################################################
# Redis (IBM Cloud Databases for Redis)
########################################################################################################################

resource "ibm_database" "redis" {
  name                        = "${var.environment_prefix}-redis"
  plan                        = "standard"
  location                    = var.region
  service                     = "databases-for-redis"
  version                     = var.redis_version
  resource_group_id           = local.resource_group_id
  service_endpoints           = "private"
  deletion_protection         = var.redis_deletion_protection
  version_upgrade_skip_backup = false
  tags                        = var.resource_tags

  group {
    group_id = "member"

    host_flavor {
      id = "multitenant"
    }

    cpu {
      allocation_count = 0
    }

    disk {
      allocation_mb = 1024
    }

    members {
      allocation_count = 2
    }

    memory {
      allocation_mb = 4096
    }
  }

  timeouts {
    create = "120m"
    update = "120m"
    delete = "15m"
  }
}

resource "ibm_resource_key" "redis_service_credentials" {
  name                 = "${var.environment_prefix}-redis-credentials"
  role                 = "Operator"
  resource_instance_id = ibm_database.redis.id
  parameters = {
    service-endpoints = "private"
  }
}

data "ibm_database_connection" "redis" {
  endpoint_type = "private"
  deployment_id = ibm_database.redis.id
  user_id       = ibm_database.redis.adminuser
  user_type     = "database"
}

locals {
  redis_host            = data.ibm_database_connection.redis.rediss[0].hosts[0].hostname
  redis_port            = data.ibm_database_connection.redis.rediss[0].hosts[0].port
  redis_username        = ibm_resource_key.redis_service_credentials.credentials["connection.rediss.authentication.username"]
  redis_pass_base64     = ibm_resource_key.redis_service_credentials.credentials["connection.rediss.authentication.password"]
  redis_certificate_b64 = data.ibm_database_connection.redis.rediss[0].certificate[0].certificate_base64
  redis_crn             = ibm_database.redis.resource_crn
}
