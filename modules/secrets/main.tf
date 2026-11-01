resource "google_secret_manager_secret" "generated" {
  for_each = var.generated_secrets

  secret_id = "${var.environment}-${each.key}"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

# Ephemeral value and write-only argument: the secret never reaches Terraform state.
ephemeral "random_password" "generated" {
  for_each = var.generated_secrets

  length  = each.value
  special = false
}

resource "google_secret_manager_secret_version" "generated" {
  for_each = var.generated_secrets

  secret                 = google_secret_manager_secret.generated[each.key].id
  secret_data_wo         = ephemeral.random_password.generated[each.key].result
  secret_data_wo_version = 1
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = var.accessors

  secret_id = google_secret_manager_secret.generated[each.value.secret].id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}
