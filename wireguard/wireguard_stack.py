from aws_cdk import core
from aws_cdk import aws_s3 as s3
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_route53 as route53
from aws_cdk import aws_iam as iam
from aws_cdk import aws_resourcegroups as rg
from aws_cdk import aws_secretsmanager as sm

class WireguardCdkStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        ### VPC and subnets
        vpc = ec2.Vpc(self, "vpc",
            cidr                 = "172.20.0.0/24",
            nat_gateways         = 0,
            max_azs              = 2,
            enable_dns_hostnames = True,
            enable_dns_support   = True,

            subnet_configuration = [
                ec2.SubnetConfiguration(
                    cidr_mask   = 26,
                    name        = "wireguard",
                    subnet_type =  ec2.SubnetType.PUBLIC)
            ]
        )

        ### Define an image and create instance
        amzn_linux = ec2.MachineImage.latest_amazon_linux(
            generation     = ec2.AmazonLinuxGeneration.AMAZON_LINUX_2,
            edition        = ec2.AmazonLinuxEdition.STANDARD,
            virtualization = ec2.AmazonLinuxVirt.HVM,
            storage        = ec2.AmazonLinuxStorage.GENERAL_PURPOSE
        )

        # Import role
        route53_role = iam.Role.from_role_arn(self, "role_id", "arn:aws:iam::585823398980:role/ec2WriteOvpnZone" )

        instance = ec2.Instance(self, "instance",
            instance_type = ec2.InstanceType("t3a.micro"),
            machine_image = amzn_linux,
            vpc           = vpc,
            role          = route53_role,
            key_name      = "wireguard-key"
        )

        instance.connections.allow_from(ec2.Peer.ipv4("109.255.202.235/32"), ec2.Port.tcp(22), "Allow ssh")
        instance.connections.allow_from_any_ipv4(ec2.Port.udp(1194), "Allow VPN traffic")

        ### DNS records
        # Pull zone object
        zone = route53.HostedZone.from_lookup(self, "zone",
            domain_name = "ovpn.gdn"
        )

        arecord = route53.ARecord(self, "record1",
            target      = route53.RecordTarget.from_ip_addresses(instance.instance_public_ip),
            zone        = zone,
            record_name = "dublin",
            ttl         = core.Duration.minutes(1)
        )

        ### Bucket
        bucket = s3.Bucket(self, "wireguard",
            bucket_name = "wireguard-conf")

        ### Resource group
        rg.CfnGroup(self, "env-group",
            name           = "wireguard",
            resource_query = rg.CfnGroup.ResourceQueryProperty(
                type  = "TAG_FILTERS_1_0",
                query = rg.CfnGroup.QueryProperty(
                    resource_type_filters = ["AWS::AllSupported"],
                    tag_filters           = [
                        rg.CfnGroup.TagFilterProperty(
                            key    = "resource-group",
                            values = ["wireguard"]
                        )
                    ]
                ) 
            )
        )