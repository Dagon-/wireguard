#!/usr/bin/env python3

from aws_cdk import core
from wireguard.wireguard_stack import WireguardCdkStack

env_eu = core.Environment(account="585823398980", region="eu-west-1")

app = core.App()
WireguardCdkStack(app, "wireguard", env=env_eu)

core.Tag.add(app, "resource-group", "wireguard",
  exclude_resource_types = ["AWS::ResourceGroups::Group"] # Tagging the resource group fails
)

app.synth()