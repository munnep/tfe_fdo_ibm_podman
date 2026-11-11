########################################################################################################################
# PostgreSQL (IBM Cloud Databases for PostgreSQL)
########################################################################################################################

resource "ibm_database" "postgres" {
  name                        = "${var.environment_prefix}-postgres"
  plan                        = "standard"
  location                    = var.region
  service                     = "databases-for-postgresql"
  version                     = "16"
  resource_group_id           = local.resource_group_id
  service_endpoints           = "private"
  deletion_protection         = var.postgres_deletion_protection
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
      allocation_mb = 5120
    }

    members {
      allocation_count = var.postgres_members
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

resource "ibm_resource_key" "postgres_service_credentials" {
  name                 = "${var.environment_prefix}-postgres-credentials"
  role                 = "Operator"
  resource_instance_id = ibm_database.postgres.id
  parameters = {
    service-endpoints = "private"
  }
}

data "ibm_database_connection" "postgres" {
  endpoint_type = "private"
  deployment_id = ibm_database.postgres.id
  user_id       = ibm_database.postgres.adminuser
  user_type     = "database"
}

locals {
  postgres_crn      = ibm_database.postgres.resource_crn
  postgres_hostname = data.ibm_database_connection.postgres.postgres[0].hosts[0].hostname
  postgres_port     = data.ibm_database_connection.postgres.postgres[0].hosts[0].port
  postgres_username = ibm_resource_key.postgres_service_credentials.credentials["connection.postgres.authentication.username"]
  postgres_password = ibm_resource_key.postgres_service_credentials.credentials["connection.postgres.authentication.password"]
}
