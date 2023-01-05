provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name = var.cluster_name
  # var.cluster_name is for Terratest
  cluster_name = var.cluster_name
  region       = var.region

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/xjbdjay/terraform-aws-eks-blueprints"
  }
}

resource "aws_security_group" "node_group_communicate" {
  name_prefix = local.cluster_name
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol  = "-1"
    from_port = 0
    to_port = 0
    self = true
  }
}


#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------

module "eks_blueprints" {
  source = "github.com/xjbdjay/terraform-aws-eks-blueprints"

  cluster_name    = local.cluster_name
  cluster_version = "1.23"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  managed_node_groups = {
    mg_2 = {
      node_group_name = "managed-ondemand-2"
      instance_types  = ["m5.large"]
      min_size        = 3
      max_size        = 10
      desired_size    = 3
      subnet_ids      = module.vpc.public_subnets
      create_launch_template = true
      public_ip = true
      launch_template_tags = {
        Name      = "eks-${local.cluster_name}"
        Group = "mg_node_2"
      }
    }
  }
  worker_additional_security_group_ids = [module.eks_blueprints.cluster_primary_security_group_id]
  # worker_additional_security_group_ids = [module.eks_blueprints.cluster_primary_security_group_id, aws_security_group.node_group_communicate.id]
  tags = local.tags
}

module "eks_blueprints_irsa_s3" {
  source = "github.com/xjbdjay/terraform-aws-eks-blueprints/modules/irsa"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_oidc_provider_arn    = module.eks_blueprints.eks_oidc_provider_arn

  kubernetes_namespace = "fdb"
  kubernetes_service_account = "s3-sa"
  irsa_iam_policies = ["arn:aws-cn:iam::aws:policy/AmazonS3FullAccess"]
  irsa_iam_role_name = "${local.name}_AmazonEKS_S3_ACCESS_Role"
}

module "eks_blueprints_kubernetes_addons" {
  source = "github.com/xjbdjay/terraform-aws-eks-blueprints/modules/kubernetes-addons"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

  # EKS Managed Add-ons
  enable_amazon_eks_vpc_cni            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true
  enable_metrics_server                = true
  metrics_server_helm_config = {
   namespace = "kube-system"
    values = [
      <<-EOT
      image:
        repository: registry.aliyuncs.com/google_containers/metrics-server
        tag: v0.6.1
      EOT
    ]
  }
  enable_cert_manager = true
  cert_manager_helm_config = {
    set_values = [
      {
        name  = "extraArgs[0]"
        value = "--enable-certificate-owner-ref=false"
      },
    ]
  }
  # TODO - requires dependency on `cert-manager` for namespace
  # enable_cert_manager_csi_driver = true

  enable_cluster_autoscaler = true
  cluster_autoscaler_helm_config = {
    set = [
      {
        name  = "podLabels.prometheus\\.io/scrape",
        value = "true",
        type  = "string",
      }
    ]
  }

  tags = local.tags
}

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

  tags = local.tags
}
