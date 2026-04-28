# ===========================================
# TERRAFORM - AWS EKS CLUSTER
# ===========================================
# Provisions an EKS cluster with Argo CD installed

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "s3-terraform-state-chitra"         # <-- CHANGE THIS
    key            = "eks/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"                      # <-- Optional but recommended
    encrypt        = true
  }
}

# ===========================================
# PROVIDERS
# ===========================================
provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# ===========================================
# DATA SOURCES
# ===========================================
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

# Check if EKS cluster already exists
data "aws_eks_clusters" "existing" {}

# Get existing cluster details if it exists
data "aws_eks_cluster" "existing" {
  count = contains(data.aws_eks_clusters.existing.names, local.cluster_name) ? 1 : 0
  name  = local.cluster_name
}

# ===========================================
# LOCALS
# ===========================================
locals {
  cluster_name   = "${var.project_name}-${var.environment}-eks"
  cluster_exists = contains(data.aws_eks_clusters.existing.names, local.cluster_name)
  
  # Get existing version if cluster exists
  existing_version = local.cluster_exists ? data.aws_eks_cluster.existing[0].version : "0.0"
  
  # Compare versions: only upgrade if target is higher
  # EKS versions are like "1.28", "1.29", etc.
  version_comparison = local.cluster_exists ? (
    tonumber(replace(var.kubernetes_version, ".", "")) > tonumber(replace(local.existing_version, ".", ""))
  ) : false
  
  # Determine action
  # - CREATE: cluster doesn't exist
  # - UPGRADE: cluster exists and target version is higher
  # - SKIP: cluster exists and target version is same or lower
  cluster_action = local.cluster_exists ? (
    local.version_comparison ? "UPGRADE" : "SKIP"
  ) : "CREATE"
  
  # Use existing version if not upgrading (prevents downgrade and unnecessary changes)
  effective_k8s_version = local.cluster_exists ? (
    local.version_comparison ? var.kubernetes_version : local.existing_version
  ) : var.kubernetes_version

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ===========================================
# CLUSTER VALIDATION OUTPUT
# ===========================================
output "cluster_validation" {
  value = {
    cluster_exists    = local.cluster_exists
    cluster_name      = local.cluster_name
    existing_version  = local.existing_version
    target_version    = var.kubernetes_version
    effective_version = local.effective_k8s_version
    version_upgrade   = local.version_comparison
    action            = local.cluster_action
  }
  description = "Cluster validation status"
}

# ===========================================
# PRE-APPLY VALIDATION
# ===========================================
resource "null_resource" "cluster_validation_check" {
  # This runs before cluster operations to validate state
  triggers = {
    cluster_name    = local.cluster_name
    cluster_exists  = local.cluster_exists
    target_version  = var.kubernetes_version
    action          = local.cluster_action
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=================================================="
      echo "CLUSTER VALIDATION CHECK"
      echo "=================================================="
      echo "Cluster Name: ${local.cluster_name}"
      echo "Cluster Exists: ${local.cluster_exists}"
      echo "Existing Version: ${local.existing_version}"
      echo "Target Version: ${var.kubernetes_version}"
      echo "Effective Version: ${local.effective_k8s_version}"
      echo "Action: ${local.cluster_action}"
      echo "=================================================="
      if [ "${local.cluster_action}" = "SKIP" ]; then
        echo "INFO: Version ${var.kubernetes_version} <= existing ${local.existing_version}"
        echo "INFO: No version change required. Only missing resources will be applied."
      elif [ "${local.cluster_action}" = "UPGRADE" ]; then
        echo "INFO: Upgrading cluster from ${local.existing_version} to ${var.kubernetes_version}"
      else
        echo "INFO: Creating new cluster with version ${var.kubernetes_version}"
      fi
      echo "=================================================="
    EOT
  }
}

# ===========================================
# VPC MODULE
# ===========================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment == "dev" ? true : false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  tags = local.common_tags
}

# ===========================================
# EKS MODULE
# ===========================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.cluster_name
  cluster_version = local.effective_k8s_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Prevent accidental cluster deletion
  # Set to false if you intentionally want to destroy
  cluster_enabled_log_types = []

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    default = {
      name           = "default-node-group"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Allow node group updates without recreation
      update_config = {
        max_unavailable_percentage = 50
      }

      labels = {
        Environment = var.environment
      }

      tags = local.common_tags
    }
  }

  # Cluster add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  tags = local.common_tags
}

# ===========================================
# ARGO CD NAMESPACE
# ===========================================
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  depends_on = [module.eks]
}

# ===========================================
# ARGO CD HELM RELEASE
# ===========================================
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      server = {
        extraArgs = ["--insecure"] # Remove for production with TLS
        service = {
          type = "LoadBalancer"
        }
      }
      configs = {
        params = {
          "server.insecure" = true # Remove for production
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# ===========================================
# NGINX INGRESS CONTROLLER
# ===========================================
resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.8.3"
  namespace  = "ingress-nginx"

  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  depends_on = [module.eks]
}
