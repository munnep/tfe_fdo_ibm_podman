########################################################################################################################
# PostgreSQL bootstrap values
#
# The database only has a private endpoint, so the extensions TFE needs are created by the TFE nodes themselves
# (scripts/init_postgres.sh.tftpl, run from cloud-init before TFE starts). This file only prepares the values.
########################################################################################################################

locals {
  postgres_extensions       = ["citext", "hstore", "pg_stat_statements", "uuid-ossp"]
  postgres_extension_schema = "ibm_extension"
  postgres_database         = data.ibm_database_connection.postgres.postgres[0].database

  postgres_extension_sql = join("\n", [
    for e in local.postgres_extensions :
    "CREATE EXTENSION IF NOT EXISTS \"${e}\" SCHEMA ${local.postgres_extension_schema};"
  ])

  # Written to /etc/tfe/postgres.env (mode 0600). Read by init_postgres.sh and usable as podman --env-file.
  postgres_env = join("\n", [
    "PGHOST=${local.postgres_hostname}",
    "PGPORT=${local.postgres_port}",
    "PGUSER=${local.postgres_username}",
    "PGPASSWORD=${local.postgres_password}",
    "PGDATABASE=${local.postgres_database}",
    "PGSSLMODE=require",
    "PGCONNECT_TIMEOUT=15",
    "",
  ])
}
