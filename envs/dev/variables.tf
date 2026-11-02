variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for all regional resources."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "hostname" {
  description = "Public hostname of the API. It must belong to the DNS zone."
  type        = string
}

variable "dns_zone_name" {
  description = "Name of the Cloud DNS zone created in bootstrap."
  type        = string
}

variable "network" {
  description = "Address ranges of the environment VPC. They must not overlap between environments."
  type = object({
    nodes_cidr      = string
    services_cidr   = string
    pods_cidr       = string
    database_cidr   = string
    proxy_only_cidr = string
  })
}

variable "database" {
  description = "Size and availability of the Cloud SQL instance."
  type = object({
    tier              = string
    availability_type = string
    disk_size_gb      = number
    backups_enabled   = bool
  })
}
