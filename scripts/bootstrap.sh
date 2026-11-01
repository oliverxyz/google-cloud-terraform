#!/usr/bin/env bash
# Applies bootstrap/ and keeps its state in the bucket it creates.
# Safe to re-run. Extra arguments go to `terraform apply`.
set -euo pipefail

cd "$(dirname "$0")/../bootstrap"

project_id="$(sed -n 's/^project_id *= *"\(.*\)"/\1/p' terraform.tfvars)"
bucket="${project_id}-tfstate"

write_backend() {
  cat > backend.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "${bucket}"
    prefix = "bootstrap"
  }
}
EOF
}

if gcloud storage buckets describe "gs://${bucket}" --project "${project_id}" >/dev/null 2>&1; then
  write_backend
  terraform init -input=false -reconfigure
  terraform apply "$@"
else
  # First run: the bucket does not exist yet, so start with local state and migrate.
  rm -f backend.tf
  terraform init -input=false
  terraform apply "$@"
  write_backend
  terraform init -input=false -migrate-state -force-copy
  rm -f terraform.tfstate terraform.tfstate.backup
fi

# The Compute API creates a default VPC with SSH and RDP open to the internet.
# Nothing here uses it, and Terraform does not own it, so remove it explicitly.
if gcloud compute networks describe default --project "${project_id}" >/dev/null 2>&1; then
  rules="$(gcloud compute firewall-rules list --project "${project_id}" \
    --filter="network:networks/default" --format="value(name)")"
  if [[ -n "${rules}" ]]; then
    # shellcheck disable=SC2086 # one rule name per word is intended
    gcloud compute firewall-rules delete ${rules} --project "${project_id}" --quiet
  fi
  gcloud compute networks delete default --project "${project_id}" --quiet
fi

terraform output
