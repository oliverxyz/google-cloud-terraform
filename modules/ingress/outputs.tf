output "hostname" {
  description = "Public hostname of the API."
  value       = var.hostname
}

output "address_name" {
  description = "Name of the static address, referenced by the Gateway."
  value       = google_compute_address.api.name
}

output "certificate_name" {
  description = "Name of the certificate, referenced by the Gateway."
  value       = google_certificate_manager_certificate.api.name
}
