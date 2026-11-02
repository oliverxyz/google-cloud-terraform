output "network_id" {
  description = "ID of the environment VPC."
  value       = module.network.network_id
}

output "secret_names" {
  description = "Secret ID per short name."
  value       = module.secrets.secret_names
}

output "database" {
  description = "Connection details of the database. The password stays in Secret Manager."
  value = {
    instance_name = module.database.instance_name
    endpoint_ip   = module.database.endpoint_ip
    database_name = module.database.database_name
    user_name     = module.database.user_name
  }
}

output "cluster" {
  description = "GKE cluster name, location and application namespace."
  value = {
    name      = module.gke.cluster_name
    location  = module.gke.cluster_location
    namespace = module.gke.namespace
  }
}

output "api_url" {
  description = "Public URL of the API."
  value       = "https://${module.ingress.hostname}"
}

output "image_prefix" {
  description = "Prefix of image references in Artifact Registry."
  value       = module.registry.image_prefix
}

output "data_bucket" {
  description = "Name of the data bucket."
  value       = module.storage.bucket_name
}

output "pubsub" {
  description = "Pub/Sub topic and subscription names."
  value = {
    documents_topic          = module.queue.documents_topic
    documents_subscription   = module.queue.documents_subscription
    dead_letter_topic        = module.queue.dead_letter_topic
    dead_letter_subscription = module.queue.dead_letter_subscription
  }
}

output "service_account_emails" {
  description = "Service account email per microservice."
  value       = module.iam.service_account_emails
}
