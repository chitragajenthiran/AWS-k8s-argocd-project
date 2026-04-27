# ===========================================
# VARIABLES - AZURE AKS
# ===========================================

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "gitops-demo"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# VNet Configuration
variable "vnet_cidr" {
  description = "VNet CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "AKS subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

# AKS Configuration
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "node_vm_size" {
  description = "VM size for worker nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "node_count" {
  description = "Initial number of nodes"
  type        = number
  default     = 2
}

variable "node_min_count" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum number of nodes"
  type        = number
  default     = 5
}

# Argo CD Configuration
variable "argocd_version" {
  description = "Argo CD Helm chart version"
  type        = string
  default     = "5.51.4"
}
