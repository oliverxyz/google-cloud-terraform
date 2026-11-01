output "instance_name" {
  description = "Name of the Cloud SQL instance."
  value       = google_sql_database_instance.this.name
}

output "endpoint_ip" {
  description = "Internal IP of the Private Service Connect endpoint. Applications connect here on port 5432."
  value       = google_compute_address.endpoint.address
}

output "database_name" {
  description = "Name of the application database."
  value       = google_sql_database.this.name
}

output "user_name" {
  description = "Name of the application database user."
  value       = google_sql_user.app.name
}

output "server_ca_cert" {
  description = "Public CA certificate of the instance, used for sslmode=verify-ca. Not a secret."
  value       = google_sql_database_instance.this.server_ca_cert[0].cert
}
