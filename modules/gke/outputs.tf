output "cluster_name" {
  description = "Name of the cluster."
  value       = google_container_cluster.this.name
}

output "cluster_location" {
  description = "Location of the cluster."
  value       = google_container_cluster.this.location
}

output "namespace" {
  description = "Kubernetes namespace of the microservices."
  value       = var.namespace
}
