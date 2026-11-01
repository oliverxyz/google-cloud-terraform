data "google_project" "this" {
  project_id = var.project_id
}

locals {
  pubsub_service_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_topic" "documents" {
  name = "${var.environment}-documents"

  message_storage_policy {
    allowed_persistence_regions = [var.region]
    enforce_in_transit          = true
  }
}

resource "google_pubsub_topic" "dead_letter" {
  name = "${var.environment}-documents-dlq"

  message_storage_policy {
    allowed_persistence_regions = [var.region]
    enforce_in_transit          = true
  }
}

resource "google_pubsub_subscription" "documents" {
  name  = "${var.environment}-documents-worker"
  topic = google_pubsub_topic.documents.id

  # Order holds per ordering key only. Delivery stays at-least-once, so consumers are idempotent.
  enable_message_ordering = true
  ack_deadline_seconds    = 60

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = var.max_delivery_attempts
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }

  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_subscription" "dead_letter" {
  name  = "${var.environment}-documents-dlq-handler"
  topic = google_pubsub_topic.dead_letter.id

  ack_deadline_seconds = 60

  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_topic_iam_member" "publisher" {
  topic  = google_pubsub_topic.documents.name
  role   = "roles/pubsub.publisher"
  member = var.publisher_member
}

resource "google_pubsub_subscription_iam_member" "subscriber" {
  subscription = google_pubsub_subscription.documents.name
  role         = "roles/pubsub.subscriber"
  member       = var.subscriber_member
}

resource "google_pubsub_subscription_iam_member" "dead_letter_subscriber" {
  subscription = google_pubsub_subscription.dead_letter.name
  role         = "roles/pubsub.subscriber"
  member       = var.dead_letter_subscriber_member
}

# Pub/Sub counts delivery attempts and forwards messages only with both of these grants.
resource "google_pubsub_topic_iam_member" "agent_dead_letter_publisher" {
  topic  = google_pubsub_topic.dead_letter.name
  role   = "roles/pubsub.publisher"
  member = local.pubsub_service_agent
}

resource "google_pubsub_subscription_iam_member" "agent_source_subscriber" {
  subscription = google_pubsub_subscription.documents.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_service_agent
}
