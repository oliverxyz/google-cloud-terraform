output "address_name" {
  description = "Name of the static address, referenced by the Gateway."
  value       = google_compute_address.public.name
}

output "services" {
  description = "Hostname and certificate name per service, referenced by the Gateway."
  value = {
    for name, hostname in var.hostnames : name => {
      hostname        = hostname
      certificateName = google_certificate_manager_certificate.service[name].name
    }
  }
}
