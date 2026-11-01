variable "project_id" {
  description = "GCP project ID, the only project allowed to connect through Private Service Connect."
  type        = string
}

variable "environment" {
  description = "Environment name, used as a resource name prefix."
  type        = string
}

variable "region" {
  description = "Region of the instance, its backups and the endpoint."
  type        = string
}

variable "network_id" {
  description = "ID of the VPC that receives the Private Service Connect endpoint."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet that holds the endpoint address."
  type        = string
}

variable "password_secret_id" {
  description = "ID of the Secret Manager secret with the application user password. A version must already exist."
  type        = string
}

variable "database_version" {
  description = "Cloud SQL database version."
  type        = string
  default     = "POSTGRES_18"
}

variable "tier" {
  description = "Machine type of the instance."
  type        = string
}

variable "availability_type" {
  description = "ZONAL, or REGIONAL for high availability."
  type        = string

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "Use ZONAL or REGIONAL."
  }
}

variable "disk_size_gb" {
  description = "SSD size in GB. Fixed, so storage cost stays predictable."
  type        = number
}

variable "backups_enabled" {
  description = "Whether automated backups are enabled. They are deleted together with the instance."
  type        = bool
}

variable "database_name" {
  description = "Name of the application database."
  type        = string
  default     = "documents"
}

variable "user_name" {
  description = "Name of the application database user."
  type        = string
  default     = "app"
}
