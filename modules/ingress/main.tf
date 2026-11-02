# The load balancer itself is created by GKE from the Gateway in the Helm chart.
# Regional Gateways do not support Premium Tier addresses.
resource "google_compute_address" "api" {
  name         = "${var.environment}-api"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
}

resource "google_dns_record_set" "api" {
  name         = "${var.hostname}."
  managed_zone = var.dns_zone_name
  type         = "A"
  ttl          = var.dns_ttl_seconds
  rrdatas      = [google_compute_address.api.address]
}

resource "google_certificate_manager_dns_authorization" "api" {
  name     = "${var.environment}-api"
  location = var.region
  domain   = var.hostname
  type     = "PER_PROJECT_RECORD"
}

resource "google_dns_record_set" "authorization" {
  name         = google_certificate_manager_dns_authorization.api.dns_resource_record[0].name
  managed_zone = var.dns_zone_name
  type         = google_certificate_manager_dns_authorization.api.dns_resource_record[0].type
  ttl          = var.dns_ttl_seconds
  rrdatas      = [google_certificate_manager_dns_authorization.api.dns_resource_record[0].data]
}

resource "google_certificate_manager_certificate" "api" {
  name     = "${var.environment}-api"
  location = var.region

  managed {
    domains            = [google_certificate_manager_dns_authorization.api.domain]
    dns_authorizations = [google_certificate_manager_dns_authorization.api.id]
  }

  depends_on = [google_dns_record_set.authorization]
}
