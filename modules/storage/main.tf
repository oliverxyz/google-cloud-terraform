resource "google_storage_bucket" "data" {
  name     = "${var.project_id}-${var.environment}-data"
  location = var.region

  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Temporary environment with no data worth keeping: destroy must leave nothing billable.
  force_destroy = true

  soft_delete_policy {
    retention_duration_seconds = 0
  }
}

resource "google_storage_bucket_iam_member" "grant" {
  for_each = var.grants

  bucket = google_storage_bucket.data.name
  role   = each.value.role
  member = each.value.member
}
