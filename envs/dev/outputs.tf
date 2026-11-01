output "network_id" {
  description = "ID of the environment VPC."
  value       = module.network.network_id
}

output "service_account_emails" {
  description = "Service account email per microservice."
  value       = module.iam.service_account_emails
}
