# ===========================================
# TERRAFORM VARIABLES - DEV ENVIRONMENT
# ===========================================

location     = "East US"
project_name = "gitops-demo"
environment  = "dev"

# VNet
vnet_cidr       = "10.0.0.0/16"
aks_subnet_cidr = "10.0.1.0/24"

# AKS
kubernetes_version = "1.28"
node_vm_size       = "Standard_D2s_v3"
node_count         = 2
node_min_count     = 1
node_max_count     = 3

# Argo CD
argocd_version = "5.51.4"
