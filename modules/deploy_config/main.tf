# GitHub Actions has no access to Terraform state, so what a deployment needs to know
# about the infrastructure is published here. Secret Manager is used for its access control.
resource "google_secret_manager_secret" "config" {
  secret_id = "${var.environment}-deploy-config"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "config" {
  secret      = google_secret_manager_secret.config.id
  secret_data = jsonencode(var.values)
}

resource "google_secret_manager_secret_iam_member" "reader" {
  secret_id = google_secret_manager_secret.config.id
  role      = "roles/secretmanager.secretAccessor"
  member    = var.reader_member
}
