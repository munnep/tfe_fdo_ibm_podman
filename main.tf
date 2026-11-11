########################################################################################################################
# Terraform Enterprise (active/active) on IBM Cloud VPC: RHEL hosts with Podman, no Kubernetes cluster
#
# All resources are defined directly in the respective .tf files:
#   resource_group.tf   - IBM Resource Group
#   cos.tf              - Cloud Object Storage instance, bucket, HMAC credentials (TFE object storage)
#   postgres.tf         - PostgreSQL (IBM Cloud Databases)
#   postgres_init.tf    - values for the PostgreSQL extension bootstrap that runs on the nodes
#   redis.tf            - Redis (IBM Cloud Databases)
#   vpc.tf              - VPC, subnets per zone, public gateways, network ACL, VPE gateways
#   security_groups.tf  - load balancer, TFE node and client security groups
#   dns_certificate.tf  - Route53 record and Let's Encrypt certificate (AWS), same as tfe_fdo_aws_podman_active-active
#   loadbalancer.tf     - public load balancer, pool and listener
#   cloudinit.tf        - cloud-init (pod spec, scripts, certificates) for the TFE nodes
#   compute.tf          - instance template and instance group (tfe_node_count nodes)
#   client.tf           - optional client VM with floating IP
########################################################################################################################
