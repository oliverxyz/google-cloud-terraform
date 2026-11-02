#!/usr/bin/env bash
# Lists everything of an environment that is still in the project after destroy.
# Exit codes: 0 nothing left, 1 resources left, 2 a check could not run.
# Usage: scripts/check-orphans.sh <env>
set -uo pipefail

env_name="${1:?usage: check-orphans.sh <env>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
project_id="$(sed -n 's/^project_id *= *"\(.*\)"/\1/p' "${root}/bootstrap/terraform.tfvars")"
region="$(sed -n 's/^region *= *"\(.*\)"/\1/p' "${root}/bootstrap/terraform.tfvars")"
domain="$(sed -n 's/^domain *= *"\(.*\)"/\1/p' "${root}/bootstrap/terraform.tfvars")"

# Prefixes of our own resources and of the ones GKE creates by itself.
compute_filter="name~^(${env_name}-|gke-${env_name}-|gk3-${env_name}-|k8s1-|k8s2-|gkegw1-)"

left=0
failed=0

check() {
  local label="$1"
  shift
  local output errors
  errors="$(mktemp)"
  # gcloud warns on stderr when a list is empty, so only stdout counts as a finding.
  if ! output="$("$@" 2>"${errors}")"; then
    echo "ERROR  ${label}: $(tail -n 1 "${errors}" | cut -c1-160)"
    failed=1
  elif [[ -n "${output}" ]]; then
    echo "LEFT   ${label}:"
    printf '         %s\n' "${output//$'\n'/$'\n'         }"
    left=1
  else
    echo "ok     ${label}"
  fi
  rm -f "${errors}"
}

gc() {
  gcloud "$@" --project "${project_id}" --format="value(name)"
}

check "GKE clusters" gc container clusters list --filter="name=${env_name}-gke"
check "Cloud SQL instances" gc sql instances list --filter="name~^${env_name}-pg-"
check "VM instances" gc compute instances list --filter="${compute_filter}"
check "disks" gc compute disks list --filter="${compute_filter}"
check "forwarding rules" gc compute forwarding-rules list --filter="${compute_filter}"
check "addresses" gc compute addresses list --filter="${compute_filter}"
check "network endpoint groups" gc compute network-endpoint-groups list --filter="${compute_filter}"
check "backend services" gc compute backend-services list --filter="${compute_filter}"
check "health checks" gc compute health-checks list --filter="${compute_filter}"
check "URL maps" gc compute url-maps list --filter="${compute_filter}"
check "target HTTPS proxies" gc compute target-https-proxies list --filter="${compute_filter}"
check "firewall rules" gc compute firewall-rules list --filter="${compute_filter}"
check "subnets" gc compute networks subnets list --filter="name~^${env_name}-"
check "routers" gc compute routers list --filter="name~^${env_name}-"
check "networks" gc compute networks list --filter="name=${env_name}-vpc"
check "secrets" gc secrets list --filter="name~/${env_name}-"
check "Pub/Sub topics" gc pubsub topics list --filter="name~/${env_name}-"
check "Pub/Sub subscriptions" gc pubsub subscriptions list --filter="name~/${env_name}-"
check "buckets" gcloud storage buckets list --project "${project_id}" --filter="name=${project_id}-${env_name}-data" --format="value(name)"
check "Artifact Registry" gc artifacts repositories list --location="${region}" --filter="name~/${env_name}-"
check "certificates" gc certificate-manager certificates list --location="${region}" --filter="name~/${env_name}-"
check "DNS authorizations" gc certificate-manager dns-authorizations list --location="${region}" --filter="name~/${env_name}-"
check "service accounts" gcloud iam service-accounts list --project "${project_id}" --filter="email~^${env_name}-" --format="value(email)"
check "DNS records" gcloud dns record-sets list --zone="${domain//./-}" --project "${project_id}" --filter="name~${env_name}\.${domain//./\\.}\.$" --format="value(name,type)"

# Private Service Connect may register endpoints here, but only with the API enabled.
if gcloud services list --enabled --project "${project_id}" --format="value(config.name)" | grep -qx servicedirectory.googleapis.com; then
  check "Service Directory namespaces" gc service-directory namespaces list --location="${region}"
else
  echo "ok     Service Directory API is not enabled"
fi

if ((failed)); then
  echo "RESULT: some checks could not run"
  exit 2
fi
if ((left)); then
  echo "RESULT: resources left for ${env_name}"
  exit 1
fi
echo "RESULT: nothing left for ${env_name}"
