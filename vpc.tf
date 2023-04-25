#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"
  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 10)]
  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }

  # enable_nat_gateway = true
  # single_nat_gateway = true
  enable_dns_hostnames = true
  enable_dns_support = true
  # enable_public_redshift = true
  tags = local.tags
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.cn-north-1.s3"
  route_table_ids = module.vpc.private_route_table_ids
  # subnet_ids = module.vpc.private_subnets
  vpc_endpoint_type = "Gateway"
}

resource "aws_vpc_endpoint" "ecr_endpoint" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "cn.com.amazonaws.cn-north-1.ecr.dkr"
  vpc_endpoint_type = "Interface"

  security_group_ids = [module.eks_blueprints.cluster_primary_security_group_id]
  subnet_ids =  slice(module.vpc.private_subnets, 0, 2)

  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api_endpoint" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "cn.com.amazonaws.cn-north-1.ecr.api"
  vpc_endpoint_type = "Interface"

  security_group_ids = [module.eks_blueprints.cluster_primary_security_group_id]
  subnet_ids = slice(module.vpc.private_subnets, 0, 2)
  private_dns_enabled = true
}


resource "aws_vpc_endpoint" "ssm_endpoint" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.cn-north-1.ssm"
  vpc_endpoint_type = "Interface"

  security_group_ids = [module.eks_blueprints.cluster_primary_security_group_id]
  subnet_ids = slice(module.vpc.private_subnets, 0, 2)
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "autoscaling_endpoint" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "cn.com.amazonaws.cn-north-1.autoscaling"
  vpc_endpoint_type = "Interface"

  security_group_ids = [module.eks_blueprints.cluster_primary_security_group_id]
  subnet_ids = slice(module.vpc.private_subnets, 0, 2)
  # subnet_ids = ["subnet-05c06a02301ed5cc1", "subnet-0ad3530a9a875f419"]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "sts_endpoint" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "cn.com.amazonaws.cn-north-1.sts"
  vpc_endpoint_type = "Interface"

  security_group_ids = [module.eks_blueprints.cluster_primary_security_group_id]
  subnet_ids = slice(module.vpc.private_subnets, 0, 2)
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2_endpoint" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "cn.com.amazonaws.cn-north-1.ec2"
  vpc_endpoint_type = "Interface"

  security_group_ids = [module.eks_blueprints.cluster_primary_security_group_id]
  subnet_ids = module.vpc.private_subnets
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "kms_endpoint" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.cn-north-1.kms"
  vpc_endpoint_type = "Interface"

  security_group_ids = [module.eks_blueprints.cluster_primary_security_group_id]
  subnet_ids = module.vpc.private_subnets
  private_dns_enabled = true
}
