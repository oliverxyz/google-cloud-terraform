output "secret_ids" {
  description = "Secret resource ID per short name."
  value       = { for name, secret in google_secret_manager_secret.generated : name => secret.id }
}

output "secret_names" {
  description = "Secret ID as used by applications, per short name."
  value       = { for name, secret in google_secret_manager_secret.generated : name => secret.secret_id }
}

output "version_ids" {
  description = "Secret version ID per short name. Depend on it to read a secret after its value exists."
  value       = { for name, version in google_secret_manager_secret_version.generated : name => version.id }
}
