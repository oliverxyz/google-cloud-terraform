variable "environment" {
  description = "Environment name, used as a resource name prefix."
  type        = string
}

variable "region" {
  description = "Region of the Autopilot cluster."
  type        = string
}

variable "network_id" {
  description = "ID of the VPC."
  type        = string
}

variable "subnet_id" {
  description = "ID of the GKE subnet."
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary range for Pods."
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary range for Services."
  type        = string
}

variable "nodes_service_account_email" {
  description = "Service account of the nodes. It cannot be changed on an existing Autopilot cluster."
  type        = string
}

variable "release_channel" {
  description = "GKE release channel."
  type        = string
  default     = "REGULAR"
}

variable "namespace" {
  description = "Kubernetes namespace of the microservices."
  type        = string
  default     = "platform"
}

variable "workload_identities" {
  description = "Kubernetes service account name => ID of the Google service account it may impersonate."
  type        = map(string)
}
