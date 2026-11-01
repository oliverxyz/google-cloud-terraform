output "state_bucket" {
  description = "Bucket holding Terraform state for bootstrap and all environments."
  value       = google_storage_bucket.terraform_state.name
}

output "dns_zone_name" {
  description = "Name of the Cloud DNS zone used by environments."
  value       = google_dns_managed_zone.public.name
}

output "dns_name_servers" {
  description = "Name servers to add as NS records for the subdomain in Cloudflare."
  value       = google_dns_managed_zone.public.name_servers
}

output "workload_identity_provider" {
  description = "Full provider name for the google-github-actions/auth action."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_service_accounts" {
  description = "Deployer service account email per environment."
  value       = { for env, account in google_service_account.deployer : env => account.email }
}
