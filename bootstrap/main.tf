locals {
  # Kept enabled after an environment is destroyed: enabled APIs have no idle cost.
  required_services = toset([
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "pubsub.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ])

  labels = {
    project    = "google-cloud-terraform"
    managed_by = "terraform"
    component  = "bootstrap"
  }
}

resource "google_project_service" "required" {
  for_each = local.required_services

  service            = each.value
  disable_on_destroy = false
}

resource "google_storage_bucket" "terraform_state" {
  name     = "${var.project_id}-tfstate"
  location = var.region
  labels   = local.labels

  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # Old state versions are the only thing that grows here.
  lifecycle_rule {
    condition {
      num_newer_versions = 5
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # Versioning already allows recovery, and removed objects stop being billed at once.
  soft_delete_policy {
    retention_duration_seconds = 0
  }

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "Identities of GitHub Actions deployment jobs."

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  # Public repository: pull requests and other branches must not get a token.
  attribute_condition = <<-EOT
    assertion.repository_owner_id == "${var.github_repository_owner_id}" &&
    assertion.repository == "${var.github_repository}" &&
    assertion.ref == "refs/heads/main" &&
    assertion.ref_type == "branch"
  EOT

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
    "attribute.environment" = "assertion.environment"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deployer" {
  for_each = var.environments

  account_id   = "deployer-${each.value}"
  display_name = "GitHub Actions deployer (${each.value})"

  depends_on = [google_project_service.required]
}

# Only a job running in the matching GitHub Environment can impersonate the account.
resource "google_service_account_iam_member" "deployer_workload_identity" {
  for_each = var.environments

  service_account_id = google_service_account.deployer[each.value].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.environment/${each.value}"
}

# Connect only. What the account may do inside a cluster comes from Kubernetes RBAC,
# which is created per environment, so dev credentials are useless against prod.
resource "google_project_iam_member" "deployer_cluster_viewer" {
  for_each = var.environments

  project = var.project_id
  role    = "roles/container.clusterViewer"
  member  = google_service_account.deployer[each.value].member
}
