output "service_account_emails" {
  description = "Service account email per microservice."
  value       = { for name, account in google_service_account.service : name => account.email }
}

output "service_account_members" {
  description = "IAM member string per microservice."
  value       = { for name, account in google_service_account.service : name => account.member }
}

output "nodes_service_account_email" {
  description = "Service account email of the GKE nodes."
  value       = google_service_account.nodes.email
}

output "nodes_service_account_member" {
  description = "IAM member string of the GKE nodes service account."
  value       = google_service_account.nodes.member
}
