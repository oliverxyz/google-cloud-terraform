resource "google_container_cluster" "this" {
  name     = "${var.environment}-gke"
  location = var.region

  enable_autopilot = true

  network    = var.network_id
  subnetwork = var.subnet_id

  # Environments are temporary: destroy must not be blocked.
  deletion_protection = false

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes = true
  }

  # kubectl goes through the DNS endpoint and is authorized by IAM, so no bastion is needed.
  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
    ip_endpoints_config {
      enabled = false
    }
  }

  # Access is limited by the roles of the service account, not by the scope.
  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = var.nodes_service_account_email
      oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    }
  }

  release_channel {
    channel = var.release_channel
  }
}

# The workload pool appears only with the cluster, hence the reference to its attribute.
resource "google_service_account_iam_member" "workload_identity" {
  for_each = var.workload_identities

  service_account_id = each.value
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${google_container_cluster.this.workload_identity_config[0].workload_pool}[${var.namespace}/${each.key}]"
}
