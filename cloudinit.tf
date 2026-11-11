########################################################################################################################
# Cloud-init for the TFE nodes
#
# The cloud-init document and the Podman pod spec are built with yamlencode(), so passwords and certificates can never
# break the YAML. Every file is sent gzip + base64 encoded to stay far below the user-data size limit.
#
# The content does NOT depend on var.tfe_node_count. Scaling out therefore never changes the instance template.
########################################################################################################################

locals {
  tfe_fqdn      = "${var.dns_hostname}.${var.dns_zonename}"
  registry_host = split("/", var.tfe_image)[0]

  cos_endpoint = "https://${
    var.cos_endpoint_type == "direct" ? ibm_cos_bucket.tfe.s3_endpoint_direct :
    var.cos_endpoint_type == "private" ? ibm_cos_bucket.tfe.s3_endpoint_private :
    ibm_cos_bucket.tfe.s3_endpoint_public
  }"

  # Full chain for the server. The trust bundle (chain + Redis service certificate) is assembled on the node by
  # install_tfe.sh, so the chain is not sent twice (keeps the user data small).
  tls_cert_pem = "${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}"
  redis_ca_pem = base64decode(local.redis_certificate_b64)

  tfe_env = {
    TFE_OPERATIONAL_MODE          = "active-active"
    TFE_LICENSE                   = var.tfe_license
    TFE_LICENSE_REPORTING_OPT_OUT = "true"
    TFE_HOSTNAME                  = local.tfe_fqdn
    TFE_HTTP_PORT                 = "8080"
    TFE_HTTPS_PORT                = "8443"
    TFE_TLS_CERT_FILE             = "/etc/ssl/private/terraform-enterprise/cert.pem"
    TFE_TLS_KEY_FILE              = "/etc/ssl/private/terraform-enterprise/key.pem"
    TFE_TLS_CA_BUNDLE_FILE        = "/etc/ssl/private/terraform-enterprise/bundle.pem"
    TFE_DISK_CACHE_VOLUME_NAME    = "terraform-enterprise_terraform-enterprise-cache"
    TFE_ENCRYPTION_PASSWORD       = var.tfe_encryption_password
    TFE_IACT_SUBNETS              = var.iact_subnets

    # Redis (IBM Cloud Databases): TLS and authentication
    TFE_REDIS_HOST         = "${local.redis_host}:${local.redis_port}"
    TFE_REDIS_USE_TLS      = "true"
    TFE_REDIS_USE_AUTH     = "true"
    TFE_REDIS_USER         = local.redis_username
    TFE_REDIS_PASSWORD     = local.redis_pass_base64
    TFE_REDIS_CA_CERT_PATH = "/etc/ssl/private/terraform-enterprise/bundle.pem"

    # PostgreSQL (IBM Cloud Databases)
    TFE_DATABASE_HOST       = "${local.postgres_hostname}:${local.postgres_port}"
    TFE_DATABASE_NAME       = local.postgres_database
    TFE_DATABASE_USER       = local.postgres_username
    TFE_DATABASE_PASSWORD   = local.postgres_password
    TFE_DATABASE_PARAMETERS = "sslmode=require"

    # Object storage: COS through its S3 API
    TFE_OBJECT_STORAGE_TYPE                    = "s3"
    TFE_OBJECT_STORAGE_S3_ENDPOINT             = local.cos_endpoint
    TFE_OBJECT_STORAGE_S3_REGION               = var.region
    TFE_OBJECT_STORAGE_S3_BUCKET               = ibm_cos_bucket.tfe.bucket_name
    TFE_OBJECT_STORAGE_S3_ACCESS_KEY_ID        = ibm_resource_key.cos.credentials["cos_hmac_keys.access_key_id"]
    TFE_OBJECT_STORAGE_S3_SECRET_ACCESS_KEY    = ibm_resource_key.cos.credentials["cos_hmac_keys.secret_access_key"]
    TFE_OBJECT_STORAGE_S3_USE_INSTANCE_PROFILE = "false"

    # The placeholder is replaced by install_tfe.sh with the private address of the node
    TFE_VAULT_CLUSTER_ADDRESS = "https://PRIVATE_IP_ADDRESS_WILL_BE_PLACED_HERE:8201"
  }

  tfe_pod = {
    apiVersion = "v1"
    kind       = "Pod"
    metadata = {
      name   = "terraform-enterprise"
      labels = { app = "terraform-enterprise" }
    }
    spec = {
      restartPolicy = "Never"
      containers = [{
        name  = "terraform-enterprise"
        image = "${var.tfe_image}:${var.tfe_release}"
        env   = [for k, v in local.tfe_env : { name = k, value = v }]
        ports = [
          { containerPort = 8443, hostPort = 443 },
          { containerPort = 8201, hostPort = 8201 },
        ]
        securityContext = {
          capabilities           = { add = ["CAP_IPC_LOCK"] }
          readOnlyRootFilesystem = true
          seLinuxOptions         = { type = "spc_t" }
        }
        volumeMounts = [
          { name = "certs", mountPath = "/etc/ssl/private/terraform-enterprise" },
          { name = "log", mountPath = "/var/log/terraform-enterprise" },
          { name = "run", mountPath = "/run" },
          { name = "tmp", mountPath = "/tmp" },
          { name = "docker-sock", mountPath = "/run/docker.sock" },
          { name = "cache", mountPath = "/var/cache/tfe-task-worker/terraform" },
        ]
      }]
      volumes = [
        { name = "certs", hostPath = { path = "/opt/tfe/certs", type = "Directory" } },
        { name = "log", emptyDir = { medium = "Memory" } },
        { name = "run", emptyDir = { medium = "Memory" } },
        { name = "tmp", emptyDir = { medium = "Memory" } },
        { name = "docker-sock", hostPath = { path = "/var/run/docker.sock", type = "File" } },
        { name = "cache", persistentVolumeClaim = { claimName = "terraform-enterprise_terraform-enterprise-cache" } },
      ]
    }
  }

  tfe_quadlet = <<-EOT
    [Unit]
    Description=Terraform Enterprise
    After=network-online.target
    Wants=network-online.target

    [Kube]
    Yaml=tfe.yaml

    [Service]
    Restart=always
    TimeoutStartSec=900

    [Install]
    WantedBy=multi-user.target
  EOT

  script_install_software = templatefile("${path.module}/scripts/install_software.sh.tftpl", {
    registry_host = local.registry_host
    swap_gb       = var.tfe_swap_gb
    data_gb       = var.tfe_data_volume_gb
  })

  script_init_postgres = templatefile("${path.module}/scripts/init_postgres.sh.tftpl", {
    attempts         = var.postgres_init_attempts
    interval         = var.postgres_init_interval
    extension_count  = length(local.postgres_extensions)
    extension_sql    = local.postgres_extension_sql
    extension_schema = local.postgres_extension_schema
    extension_list   = join(",", [for e in local.postgres_extensions : "'${e}'"])
    client_image     = var.postgres_client_image
  })

  script_install_tfe = templatefile("${path.module}/scripts/install_tfe.sh.tftpl", {
    registry_host = local.registry_host
    image         = "${var.tfe_image}:${var.tfe_release}"
  })

  registry_env = join("\n", [
    "REGISTRY_USERNAME=${var.tfe_registry_username}",
    "REGISTRY_PASSWORD=${coalesce(var.tfe_registry_password, var.tfe_license)}",
    "",
  ])

  server_files = [
    { path = "/opt/tfe/certs/cert.pem", permissions = "0644", content = local.tls_cert_pem },
    # 0644: the TFE container does not run as root inside the pod. The node is single purpose and not shared.
    { path = "/opt/tfe/certs/key.pem", permissions = "0644", content = acme_certificate.certificate.private_key_pem },
    { path = "/opt/tfe/certs/redis-ca.pem", permissions = "0644", content = local.redis_ca_pem },
    { path = "/etc/tfe/postgres.env", permissions = "0600", content = local.postgres_env },
    { path = "/etc/tfe/registry.env", permissions = "0600", content = local.registry_env },
    { path = "/etc/containers/systemd/tfe.yaml", permissions = "0600", content = yamlencode(local.tfe_pod) },
    { path = "/etc/containers/systemd/terraform-enterprise.kube", permissions = "0644", content = local.tfe_quadlet },
    { path = "/var/tmp/install_software.sh", permissions = "0750", content = local.script_install_software },
    { path = "/var/tmp/init_postgres.sh", permissions = "0750", content = local.script_init_postgres },
    { path = "/var/tmp/install_tfe.sh", permissions = "0750", content = local.script_install_tfe },
  ]

  # The three steps run one after the other. install_tfe.sh refuses to start without the postgres marker.
  tfe_user_data = "#cloud-config\n${yamlencode({
    write_files = [
      for f in local.server_files : {
        path        = f.path
        permissions = f.permissions
        owner       = "root:root"
        encoding    = "gz+b64"
        content     = base64gzip(f.content)
      }
    ]
    runcmd = [
      "bash /var/tmp/install_software.sh",
      "bash /var/tmp/init_postgres.sh",
      "bash /var/tmp/install_tfe.sh",
    ]
  })}"

  client_user_data = templatefile("${path.module}/scripts/cloudinit_tfe_client.yaml.tftpl", {
    terraform_package = var.terraform_client_version == "" ? "terraform" : "terraform=${var.terraform_client_version}"
  })
}
