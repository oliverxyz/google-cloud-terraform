# The load balancer itself is created by GKE from the Gateway in the Helm chart.
# Regional Gateways do not support Premium Tier addresses.
resource "google_compute_address" "public" {
  name         = "${var.environment}-public"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
}

resource "google_dns_record_set" "service" {
  for_each = var.hostnames

  name         = "${each.value}."
  managed_zone = var.dns_zone_name
  type         = "A"
  ttl          = var.dns_ttl_seconds
  rrdatas      = [google_compute_address.public.address]
}

resource "google_certificate_manager_dns_authorization" "service" {
  for_each = var.hostnames

  name     = "${var.environment}-${each.key}"
  location = var.region
  domain   = each.value
  type     = "PER_PROJECT_RECORD"
}

resource "google_dns_record_set" "authorization" {
  for_each = var.hostnames

  name         = google_certificate_manager_dns_authorization.service[each.key].dns_resource_record[0].name
  managed_zone = var.dns_zone_name
  type         = google_certificate_manager_dns_authorization.service[each.key].dns_resource_record[0].type
  ttl          = var.dns_ttl_seconds
  rrdatas      = [google_certificate_manager_dns_authorization.service[each.key].dns_resource_record[0].data]
}

resource "google_certificate_manager_certificate" "service" {
  for_each = var.hostnames

  name     = "${var.environment}-${each.key}"
  location = var.region

  managed {
    domains            = [google_certificate_manager_dns_authorization.service[each.key].domain]
    dns_authorizations = [google_certificate_manager_dns_authorization.service[each.key].id]
  }

  depends_on = [google_dns_record_set.authorization]
}
