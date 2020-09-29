#!/usr/bin/env python3

import os
from aws_cdk import core
from wireguard.wireguard_stack import WireguardCdkStack

env_eu = core.Environment(
    account=os.environ["CDK_DEFAULT_ACCOUNT"],
    region=os.environ["CDK_DEFAULT_REGION"]
)

app = core.App()
WireguardCdkStack(app, "wireguard", env=env_eu)

core.Tag.add(app, "resource-group", "wireguard",
	exclude_resource_types = ["AWS::ResourceGroups::Group"] # Tagging the resource group fails
)

app.synth()