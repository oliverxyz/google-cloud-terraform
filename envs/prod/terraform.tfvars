project_id  = "infrastructure-test-plan"
region      = "europe-southwest1"
environment = "prod"

hostname      = "api.cloud.oliverolsson.xyz"
web_hostname  = "cloud.oliverolsson.xyz"
dns_zone_name = "cloud-oliverolsson-xyz"

network = {
  nodes_cidr      = "10.30.0.0/22"
  services_cidr   = "10.30.4.0/22"
  database_cidr   = "10.30.8.0/28"
  proxy_only_cidr = "10.30.12.0/23"
  pods_cidr       = "10.30.128.0/17"
}

database = {
  tier              = "db-custom-1-3840"
  availability_type = "REGIONAL"
  disk_size_gb      = 20
  backups_enabled   = true
}
