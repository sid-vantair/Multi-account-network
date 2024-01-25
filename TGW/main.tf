provider "aws" {
  region = local.region
}

# This provider is required for attachment only installation in another AWS Account
provider "aws" {
  region = local.region
  alias  = "peer"
  # This role is created to get access to the other AWS account
  assume_role {
      role_arn = "arn:aws:iam::552630710301:role/tgw-peering"
     }
}

locals {
  name   = "tgw-${replace(basename(path.cwd), "_", "-")}"
  region = "us-east-1"

  tags = {
    Example    = local.name
  }
}

################################################################################
# Transit Gateway Module
################################################################################

module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"

  name            = local.name
  description     = "My TGW shared with several other AWS accounts"
  amazon_side_asn = 64532
  enable_auto_accept_shared_attachments = true
  share_tgw              = true

  vpc_attachments = {
    vpc1 = {
      vpc_id       = module.vpc1.vpc_id
      subnet_ids   = module.vpc1.private_subnets
      dns_support  = true
      ipv6_support = false

      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false

      tgw_routes = [
        {
          destination_cidr_block = "30.0.0.0/16"
        },
        {
          blackhole              = true
          destination_cidr_block = "0.0.0.0/0"
        }
      ]
    }   
  }

   ram_allow_external_principals = true
   ram_principals                = [552630710301] #AWS Account number that's allowed to access the TGW

  tags = local.tags
}

module "tgw_peer" {
  source  = "terraform-aws-modules/transit-gateway/aws"
  
  #This connects to the other AWS account
  providers = {
    aws = aws.peer
  }

  name            = "${local.name}-peer"
  description     = "My TGW shared with several other AWS accounts"

  create_tgw             = false
  ram_resource_share_arn = module.tgw.ram_resource_share_id
  enable_auto_accept_shared_attachments = false

  vpc_attachments = {
    vpc2 = {
      tgw_id       = module.tgw.ec2_transit_gateway_id
      vpc_id       = module.vpc2.vpc_id
      subnet_ids   = module.vpc2.private_subnets
      dns_support  = true
      ipv6_support = false

      transit_gateway_default_route_table_association = false
      transit_gateway_default_route_table_propagation = false

      tgw_routes = [
        {
          destination_cidr_block = "30.0.0.0/16"
        },
        {
          blackhole              = true
          destination_cidr_block = "0.0.0.0/0"
        }
      ]
    } 
  }

  tags = local.tags
}

################################################################################
# Supporting resources
################################################################################

module "vpc1" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "${local.name}-vpc1"
  cidr = "10.10.0.0/16"

  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]

  enable_ipv6 = false

  tags = local.tags
}


module "vpc2" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  providers = {
    aws = aws.peer
  }

  name = "${local.name}-vpc2"
  cidr = "10.20.0.0/16"

  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
  private_subnets = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]

  enable_ipv6 = false

  tags = local.tags
}
