output "network_id" {
  description = "ID of the VPC."
  value       = google_compute_network.this.id
}

output "gke_subnet_id" {
  description = "ID of the GKE subnet."
  value       = google_compute_subnetwork.gke.id
}

output "database_subnet_id" {
  description = "ID of the subnet for the database Private Service Connect endpoint."
  value       = google_compute_subnetwork.database.id
}

output "pods_range_name" {
  description = "Name of the secondary range for Pods."
  value       = local.pods_range_name
}

output "services_range_name" {
  description = "Name of the secondary range for Services."
  value       = local.services_range_name
}
