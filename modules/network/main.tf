locals {
  pods_range_name     = "pods"
  services_range_name = "services"
}

resource "google_compute_network" "this" {
  name                    = "${var.environment}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Nodes have no external IPs and there is no Cloud NAT, so the default route
# only carries traffic to Google APIs through Private Google Access.
resource "google_compute_subnetwork" "gke" {
  name                     = "${var.environment}-gke"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.nodes_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = local.pods_range_name
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = local.services_range_name
    ip_cidr_range = var.services_cidr
  }
}

resource "google_compute_subnetwork" "database" {
  name          = "${var.environment}-db-psc"
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.database_cidr
}

# The GKE Gateway controller places the load balancer proxies here, one subnet per region and VPC.
resource "google_compute_subnetwork" "proxy_only" {
  name          = "${var.environment}-proxy-only"
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = var.proxy_only_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_firewall" "allow_database_egress" {
  name        = "${var.environment}-allow-db-egress"
  description = "Allow only the database port towards the database subnet."
  network     = google_compute_network.this.id
  direction   = "EGRESS"
  priority    = 1000

  destination_ranges = [var.database_cidr]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.database_port)]
  }
}

# VPC egress is open by default, so everything else has to be denied explicitly.
resource "google_compute_firewall" "deny_database_egress" {
  name        = "${var.environment}-deny-db-egress"
  description = "Deny all other traffic towards the database subnet."
  network     = google_compute_network.this.id
  direction   = "EGRESS"
  priority    = 1100

  destination_ranges = [var.database_cidr]

  deny {
    protocol = "all"
  }
}
