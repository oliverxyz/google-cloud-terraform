variable "environment" {
  description = "Environment name, used as a resource name prefix."
  type        = string
}

variable "region" {
  description = "The only region that holds the secret replica."
  type        = string
}

variable "reader_member" {
  description = "IAM member allowed to read the configuration, normally the GitHub Actions deployer."
  type        = string
}

variable "values" {
  description = "Helm values for the deployment. Only non-secret data: stored in Terraform state."
  type        = any
}
