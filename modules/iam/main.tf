# Service accounts only. Each resource module grants access on its own resource,
# so no microservice holds a project-wide role.
resource "google_service_account" "service" {
  for_each = var.services

  account_id   = "${var.environment}-${each.value}"
  display_name = "${each.value} microservice (${var.environment})"
}

resource "google_service_account" "nodes" {
  account_id   = "${var.environment}-gke-nodes"
  display_name = "GKE nodes (${var.environment})"
}

resource "google_project_iam_member" "nodes_default" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = google_service_account.nodes.member
}
