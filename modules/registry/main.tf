resource "google_artifact_registry_repository" "images" {
  repository_id = "${var.environment}-images"
  location      = var.region
  format        = "DOCKER"
  description   = "Container images of the ${var.environment} environment. Deleted and rebuilt with it."
}

resource "google_artifact_registry_repository_iam_member" "reader" {
  repository = google_artifact_registry_repository.images.name
  location   = google_artifact_registry_repository.images.location
  role       = "roles/artifactregistry.reader"
  member     = var.reader_member
}

resource "google_artifact_registry_repository_iam_member" "writer" {
  repository = google_artifact_registry_repository.images.name
  location   = google_artifact_registry_repository.images.location
  role       = "roles/artifactregistry.writer"
  member     = var.writer_member
}
