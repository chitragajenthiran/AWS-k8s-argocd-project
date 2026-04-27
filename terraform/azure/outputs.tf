# ===========================================
# OUTPUTS - AZURE AKS
# ===========================================

output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "AKS cluster ID"
  value       = azurerm_kubernetes_cluster.main.id
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "kube_config" {
  description = "Kubernetes config (sensitive)"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "argocd_server_url" {
  description = "Argo CD server URL (get via kubectl)"
  value       = "kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}

output "argocd_initial_password" {
  description = "Command to get Argo CD initial admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "node_resource_group" {
  description = "Node resource group name"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}
