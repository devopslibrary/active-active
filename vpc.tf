# ------------------------------------------------------------------------------
# VPC Creation, the very first thing that runs
# ------------------------------------------------------------------------------

# Virginia VPC
module "virginia-vpc" {
  name            = "virginia-vpc"
  source          = "terraform-aws-modules/vpc/aws"
  version         = "2.39.0"
  cidr            = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  enable_vpn_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform                                = "true"
    "kubernetes.io/cluster/virginia-cluster" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/virginia-cluster" = "shared"
    "kubernetes.io/role/elb"                 = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/virginia-cluster" = "shared"
    "kubernetes.io/role/internal-elb"        = "1"
  }
  providers = {
    aws = aws.virginia
  }
}

# Ohio VPC
module "ohio-vpc" {
  name            = "ohio-vpc"
  source          = "terraform-aws-modules/vpc/aws"
  version         = "2.39.0"
  cidr            = "10.1.0.0/16"
  azs             = ["us-east-2a", "us-east-2b"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24"]

  enable_nat_gateway   = true
  enable_vpn_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform                            = "true"
    "kubernetes.io/cluster/ohio-cluster" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/ohio-cluster" = "shared"
    "kubernetes.io/role/elb"             = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/ohio-cluster" = "shared"
    "kubernetes.io/role/internal-elb"    = "1"
  }
  providers = {
    aws = aws.ohio
  }
}

# ------------------------------------------------------------------------------
# VPC Peering, time to connect our VPCs and update route tables for both.
# We have to create the peering connection from one and accept it on the other.
# ------------------------------------------------------------------------------

# Set up peering connection from Virginia --> Ohio
resource "aws_vpc_peering_connection" "virginia-to-ohio" {
  provider    = aws.virginia
  peer_vpc_id = module.ohio-vpc.vpc_id
  vpc_id      = module.virginia-vpc.vpc_id
  peer_region = "us-east-2" # Ohio
}

# Ohio will be nice and accept Virginia's invitation <3
resource "aws_vpc_peering_connection_accepter" "peer-accepter" {
  provider                  = aws.ohio
  vpc_peering_connection_id = aws_vpc_peering_connection.virginia-to-ohio.id
  auto_accept               = true
}

# And lastly, add routes in both VPCs to each other
resource "aws_route" "virginia-to-ohio-routes" {
  provider                  = aws.virginia
  count                     = length(module.virginia-vpc.private_route_table_ids)
  route_table_id            = module.virginia-vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.ohio-vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.virginia-to-ohio.id
}
resource "aws_route" "ohio-to-virginia-routes" {
  provider                  = aws.ohio
  count                     = length(module.ohio-vpc.private_route_table_ids)
  route_table_id            = module.ohio-vpc.private_route_table_ids[count.index]
  destination_cidr_block    = module.virginia-vpc.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.virginia-to-ohio.id
}

# ------------------------------------------------------------------------------
# And security groups to allow free flow traffic between both CIDRs
# ------------------------------------------------------------------------------
resource "aws_security_group" "allow-traffic-from-ohio-vpc" {
  name        = "allow-traffic-from-ohio-vpc"
  provider    = aws.virginia
  description = "Allow all traffic from Ohio private CIDR"
  vpc_id      = module.virginia-vpc.vpc_id

  ingress {
    description = "All Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.ohio-vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-traffic-from-ohio-vpc"
  }
}

resource "aws_security_group" "allow-traffic-from-virginia-vpc" {
  name        = "allow-traffic-virginia-vpc"
  provider    = aws.ohio
  description = "Allow all traffic from Virginia private CIDR"
  vpc_id      = module.ohio-vpc.vpc_id

  ingress {
    description = "All Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.virginia-vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-traffic-from-virginia-vpc"
  }
}