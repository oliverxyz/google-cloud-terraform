variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "environment" {
  description = "Environment name, used as a resource name prefix."
  type        = string
}

variable "services" {
  description = "Microservices that each receive their own service account."
  type        = set(string)
  default     = ["api", "worker", "dlq-handler", "reporter"]
}
