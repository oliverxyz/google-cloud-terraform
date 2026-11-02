#!/usr/bin/env bash
# Removes an environment completely and checks that nothing is left.
# GKE creates the load balancer itself, so workloads go first: otherwise Terraform
# would find its IP, certificate and subnet still in use.
# Usage: scripts/down.sh <env> [terraform destroy arguments]
set -euo pipefail

env_name="${1:?usage: down.sh <env> [terraform destroy arguments]}"
shift
root="$(cd "$(dirname "$0")/.." && pwd)"
project_id="$(sed -n 's/^project_id *= *"\(.*\)"/\1/p' "${root}/bootstrap/terraform.tfvars")"
region="$(sed -n 's/^region *= *"\(.*\)"/\1/p' "${root}/bootstrap/terraform.tfvars")"
cluster="${env_name}-gke"
namespace="platform"

if [[ -n "$(gcloud container clusters list --project "${project_id}" --filter="name=${cluster}" --format="value(name)")" ]]; then
  gcloud container clusters get-credentials "${cluster}" --location "${region}" --project "${project_id}" --dns-endpoint
  kubectl delete namespace "${namespace}" --ignore-not-found --timeout=10m

  echo "Waiting for GKE to remove the load balancer..."
  for _ in $(seq 1 60); do
    rules="$(gcloud compute forwarding-rules list --project "${project_id}" \
      --filter="network~/${env_name}-vpc$ AND NOT name=${env_name}-db-endpoint" --format="value(name)")"
    [[ -z "${rules}" ]] && break
    sleep 10
  done
  if [[ -n "${rules}" ]]; then
    echo "Load balancer is still there: ${rules}" >&2
    exit 1
  fi
fi

cd "${root}/envs/${env_name}"
terraform init -input=false
terraform destroy "$@"

"${root}/scripts/check-orphans.sh" "${env_name}"
