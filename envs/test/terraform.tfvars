project_id  = "infrastructure-test-plan"
region      = "europe-southwest1"
environment = "test"

hostname      = "api.test.cloud.oliverolsson.xyz"
web_hostname  = "web.test.cloud.oliverolsson.xyz"
dns_zone_name = "cloud-oliverolsson-xyz"

network = {
  nodes_cidr      = "10.20.0.0/22"
  services_cidr   = "10.20.4.0/22"
  database_cidr   = "10.20.8.0/28"
  proxy_only_cidr = "10.20.12.0/23"
  pods_cidr       = "10.20.128.0/17"
}

database = {
  tier              = "db-g1-small"
  availability_type = "ZONAL"
  disk_size_gb      = 10
  backups_enabled   = false
}
