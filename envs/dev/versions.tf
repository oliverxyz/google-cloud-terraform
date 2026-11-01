terraform {
  required_version = "~> 1.16"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 8.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.9.1"
    }
  }

  backend "gcs" {
    bucket = "infrastructure-test-plan-tfstate"
    prefix = "envs/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    project     = "google-cloud-terraform"
    environment = var.environment
    managed_by  = "terraform"
  }
}
