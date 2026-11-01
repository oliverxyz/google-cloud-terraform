output "documents_topic" {
  description = "Name of the documents topic."
  value       = google_pubsub_topic.documents.name
}

output "documents_subscription" {
  description = "Name of the documents subscription."
  value       = google_pubsub_subscription.documents.name
}

output "dead_letter_topic" {
  description = "Name of the dead-letter topic."
  value       = google_pubsub_topic.dead_letter.name
}

output "dead_letter_subscription" {
  description = "Name of the dead-letter subscription."
  value       = google_pubsub_subscription.dead_letter.name
}
