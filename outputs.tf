output "id" {
  description = "ID to pass other modules in order to refer to this module as a dependency."
  value       = resource.null_resource.this.id
}

output "cluster_dns" {
  description = "Jupyterhub cluster dns"
  value       = "jupyterhub.jupyterhub.svc.cluster.local"
}
output "cluster_ip" {
  description = "Jupyterhub cluster ip internal"
  value       = try(data.kubernetes_service_v1.jupyterhub.spec[0].cluster_ip, null)
}

output "endpoint" {
  description = "Jupyterhub endpoint external"
  value       = local.domain
}
