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

#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------

module "eks_blueprints" {
  source = "github.com/xjbdjay/terraform-aws-eks-blueprints"

  cluster_name    = local.cluster_name
  cluster_version = "1.25"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  cluster_endpoint_private_access = true
# loadbalancer need one security_group_tags with this tag
  node_security_group_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = null
  }

  managed_node_groups = {
    mg_2 = {
      node_group_name = "managed-ondemand-2"
      instance_types  = ["m5.large"]
      # capacity_type = "SPOT"
      min_size        = 3
      max_size        = 10
      desired_size    = 3
      subnet_ids      = module.vpc.private_subnets
      create_launch_template = true
      # public_ip = true
      k8s_labels = {
        category = "static"
      }
      launch_template_tags = {
        Name      = "eks-${local.cluster_name}"
        Group = "mg_node_2"
      }
    }
    # mg_1 = {
    #   node_group_name = "managed-ondemand-2"
    #   instance_types  = ["m5.large"]
    #   capacity_type = "SPOT"
    #   min_size        = 3
    #   max_size        = 10
    #   desired_size    = 3
    #   subnet_ids      = module.vpc.public_subnets
    #   create_launch_template = true
    #   public_ip = true
    #   k8s_labels = {
    #     category = "static"
    #   }
    #   launch_template_tags = {
    #     Name      = "eks-${local.cluster_name}"
    #     Group = "mg_node_2"
    #   }
    # }
  }
  worker_additional_security_group_ids = [module.eks_blueprints.cluster_primary_security_group_id]
  # worker_additional_security_group_ids = [module.eks_blueprints.cluster_primary_security_group_id, aws_security_group.node_group_communicate.id]
  tags = local.tags
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
        repository: 635304352795.dkr.ecr.cn-north-1.amazonaws.com.cn/metrics-server
        tag: latest
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
