provider "aws" {
  profile    = "default"
  region     = "eu-west-1"
  access_key = ""
  secret_key = ""
}

#### Variables / data

variable "external_ip" {
  type    = list(string)
  default = ["109.255.202.235/32"]
}

variable "vpc_cidr" {
  type    = string
  default = "172.20.0.0/24"
}

variable "subnet_cidr" {
  type    = string
  default = "172.20.0.0/24"
}

variable "public_key" {
  type    = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJ5P4OjqK9dRz+XDMMVBpeUktuDOzHl9IgFMmmMBFT9YJzp/aBKF8jAPDBkRAdr9Bv0zoejWpMeX11i0LdCxyzIBJ0IxH2nP/oTjcqS3Ti/Skd1Y9FTXvbBycvnlWRKBikjiQyFWE5gEVI6lPW8S3hkMtowdAbelpuCOtSzjZv7WFCaSpIAAiLB++MVjKeT7MvFZOh9tTkBpv1Weq9mJtdvbS4dqbqzkkGs3i/Dl2ttv3R80oJL7uK+0k7Ci9odi4ZWxSbqFwF6XmS5Z55tIictRmSgaut7+DA1YUo2EhqVof+CtbKNibYJfFVfuYsNjYvhLZR1Ly8IjGLtXHEicY9"
}

data "aws_route53_zone" "vpn" {
  name = "ovpn.gdn."
}

#### Resouce group
resource "aws_resourcegroups_group" "vpn_group" {
  name = "vpn-rg"

  resource_query {
    query = <<JSON
        {
            "ResourceTypeFilters": ["AWS::AllSupported"],
            "TagFilters": [
                {
                    "Key": "vpn-resource",
                    "Values": ["true"]
                }
            ]
        }
    JSON
  }
}

#### Instance
resource "aws_instance" "vpn" {
  ami           = "ami-04d5cc9b88f9d1d39"
  instance_type = "t3a.nano"

  iam_instance_profile = "ec2WriteOvpnZone"

  subnet_id                   = aws_subnet.vpn_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.vpn_security_group.id]
  key_name                    = "vpn-key"

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = "8"
  }

  volume_tags = {
    Name         = "vpn-volume"
    vpn-resource ="tcp"
  }

  tags = {
    Name         = "vpn"
    vpn-resource = "true"
  }

}

resource "aws_key_pair" "vpn" {
  key_name   = "vpn-key"
  public_key = var.public_key
}

resource "aws_security_group" "vpn_security_group" {

  name          = "vpn-sg"
  description   = "Allow inbound vpn traffic"
  vpc_id        = aws_vpc.vpn_vpc.id

  ingress {
    description = "vpn inbound"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = var.external_ip
  }

  ingress {
    description = "ssh inbound"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.external_ip
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name         = "vpn-sg"
    vpn-resource = "true"
  }
}



#### Networking
resource "aws_vpc" "vpn_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name         = "vpn-vpc"
    vpn-resource = "true"
  }
}

resource "aws_subnet" "vpn_subnet" {
  vpc_id     = aws_vpc.vpn_vpc.id
  cidr_block = var.subnet_cidr

  tags = {
    Name         = "vpn-sn"
    vpn-resource = "true"
  }
}

resource "aws_internet_gateway" "vpn_gateway" {
  vpc_id = aws_vpc.vpn_vpc.id

  tags = {
    Name         = "vpn-gateway"
    vpn-resource = "true"
  }
}

resource "aws_route_table" "vpn_routetable" {
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpn_gateway.id
  }

  tags = {
    Name         = "vpn-routetable"
    vpn-resource = "true"
  }
}

resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.vpn_vpc.default_route_table_id
}

resource "aws_route_table_association" "vpn_route_subnet_assoc" {
  subnet_id      = aws_subnet.vpn_subnet.id
  route_table_id = aws_route_table.vpn_routetable.id
}

resource "aws_route53_record" "record1" {
  zone_id = data.aws_route53_zone.vpn.zone_id
  name    = "dublin.${data.aws_route53_zone.vpn.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.vpn.public_ip]
}