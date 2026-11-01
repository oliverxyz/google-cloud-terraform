# Cloud SQL may keep a deleted instance name reserved, which would break a fast recreate.
resource "random_id" "instance_suffix" {
  byte_length = 2
}

resource "google_sql_database_instance" "this" {
  name             = "${var.environment}-pg-${random_id.instance_suffix.hex}"
  region           = var.region
  database_version = var.database_version

  # Environments are temporary and hold no data worth keeping: destroy must not be blocked.
  deletion_protection = false

  settings {
    edition                     = "ENTERPRISE"
    tier                        = var.tier
    availability_type           = var.availability_type
    disk_type                   = "PD_SSD"
    disk_size                   = var.disk_size_gb
    disk_autoresize             = false
    deletion_protection_enabled = false

    ip_configuration {
      ipv4_enabled = false
      ssl_mode     = "ENCRYPTED_ONLY"

      psc_config {
        psc_enabled               = true
        allowed_consumer_projects = [var.project_id]
      }
    }

    backup_configuration {
      enabled = var.backups_enabled
      # The API does not keep a location while backups are off, which would show as a permanent diff.
      location = var.backups_enabled ? var.region : null
    }
  }
}

resource "google_sql_database" "this" {
  name     = var.database_name
  instance = google_sql_database_instance.this.name

  # Removed together with the instance. Postgres refuses to drop objects that are still in use.
  deletion_policy = "ABANDON"
}

# The password comes from Secret Manager, not from the generator, so that a failed apply
# cannot leave the secret and the database user with different values.
ephemeral "google_secret_manager_secret_version" "password" {
  secret = var.password_secret_id
}

resource "google_sql_user" "app" {
  name                = var.user_name
  instance            = google_sql_database_instance.this.name
  password_wo         = ephemeral.google_secret_manager_secret_version.password.secret_data
  password_wo_version = 1

  # Removed together with the instance. Postgres refuses to drop a role that owns objects.
  deletion_policy = "ABANDON"
}

resource "google_compute_address" "endpoint" {
  name         = "${var.environment}-db-endpoint"
  region       = var.region
  subnetwork   = var.subnet_id
  address_type = "INTERNAL"
}

resource "google_compute_forwarding_rule" "endpoint" {
  name   = "${var.environment}-db-endpoint"
  region = var.region

  # An empty scheme with a service attachment target is what makes this a PSC endpoint.
  load_balancing_scheme = ""
  target                = google_sql_database_instance.this.psc_service_attachment_link
  network               = var.network_id
  ip_address            = google_compute_address.endpoint.id
}
