variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for all regional resources, including Terraform state."
  type        = string
}

variable "environments" {
  description = "Environments that receive their own GitHub Actions deployer service account."
  type        = set(string)
  default     = ["dev", "test", "prod"]
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy, in owner/name format."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "Use the owner/name format."
  }
}

variable "github_repository_owner_id" {
  description = "Numeric GitHub owner ID. Protects against a re-registered owner name."
  type        = string
}
