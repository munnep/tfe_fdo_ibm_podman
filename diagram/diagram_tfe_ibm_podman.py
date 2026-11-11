from diagrams import Cluster, Diagram, Edge
from diagrams.aws.network import Route53
from diagrams.ibm.compute import Instance
from diagrams.ibm.data import Caches, DataServices
from diagrams.ibm.network import Gateway, LoadBalancer, PublicGateway
from diagrams.ibm.storage import ObjectStorage
from diagrams.ibm.user import User

# Variables
title = "TFE Active-Active on IBM Cloud with RHEL and Podman"
outformat = "png"
filename = "diagram/diagram_tfe_ibm_podman"
direction = "LR"

with Diagram(
    name=title,
    direction=direction,
    filename=filename,
    outformat=outformat,
    show=False,
) as diag:
    user = User("Users / terraform CLI\n/ agents")

    with Cluster("AWS"):
        route53 = Route53("Route53\nCNAME to load balancer\n+ Let's Encrypt DNS-01")

    with Cluster("IBM Cloud"):
        # Managed regional services (outside the VPC, reached over private endpoints)
        cos = ObjectStorage("Cloud Object Storage\n(TFE state & assets)")
        postgres = DataServices("Databases for PostgreSQL")
        redis = Caches("Databases for Redis")

        with Cluster("IBM VPC"):
            lb = LoadBalancer("Public load balancer\nTCP 443 passthrough")
            client = Instance("Optional client VM\n(floating IP, SSH jump host)")
            postgres_vpe = Gateway("PostgreSQL VPE")
            redis_vpe = Gateway("Redis VPE")

            with Cluster("Instance group (tfe_node_count nodes)"):
                with Cluster("Zone 1 subnet"):
                    node1 = Instance("RHEL + Podman\nTFE node")
                    pgw1 = PublicGateway("Public gateway")

                with Cluster("Zone 2 subnet"):
                    node2 = Instance("RHEL + Podman\nTFE node")
                    pgw2 = PublicGateway("Public gateway")

    user >> Edge(label="HTTPS 443") >> route53
    route53 >> lb
    lb >> [node1, node2]

    node1 >> Edge(
        xlabel="8201 vault",
        style="bold",
        color="darkgreen",
        fontcolor="darkgreen",
        dir="both",
        arrowtail="normal",
        penwidth="2",
    ) >> node2

    # Both nodes use the same services; one edge per service keeps the diagram readable
    node1 >> Edge(label="private endpoint") >> postgres_vpe
    node1 >> Edge(label="private endpoint") >> redis_vpe
    postgres_vpe >> Edge(color="blue", style="dashed") >> postgres
    redis_vpe >> Edge(color="blue", style="dashed") >> redis
    node1 >> Edge(label="S3 API (VPC direct endpoint)") >> cos

    client >> Edge(label="ssh", style="dashed") >> node1

diag
