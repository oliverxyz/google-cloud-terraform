#!/usr/bin/env bash
# Builds the images and deploys the chart. The same script runs locally and in GitHub Actions,
# with no access to Terraform state: infrastructure values come from <env>-deploy-config.
# Usage: scripts/deploy.sh <env> [image tag]
set -euo pipefail

env_name="${1:?usage: deploy.sh <env> [image tag]}"
root="$(cd "$(dirname "$0")/.." && pwd)"
project_id="$(sed -n 's/^project_id *= *"\(.*\)"/\1/p' "${root}/bootstrap/terraform.tfvars")"
region="$(sed -n 's/^region *= *"\(.*\)"/\1/p' "${root}/bootstrap/terraform.tfvars")"
tag="${2:-$(git -C "${root}" rev-parse --short=12 HEAD)}"
image_prefix="${region}-docker.pkg.dev/${project_id}/${env_name}-images"

config="$(mktemp)"
trap 'rm -f "${config}"' EXIT
gcloud secrets versions access latest --secret "${env_name}-deploy-config" --project "${project_id}" > "${config}"

gcloud auth configure-docker "${region}-docker.pkg.dev" --quiet
gcloud container clusters get-credentials "${env_name}-gke" \
  --location "${region}" --project "${project_id}" --dns-endpoint

# Image name uses the Kubernetes name, the Dockerfile lives in the Python package.
for pair in api:api worker:worker dlq-handler:dlq_handler reporter:reporter; do
  name="${pair%%:*}"
  package="${pair##*:}"
  docker build -f "${root}/services/${package}/Dockerfile" -t "${image_prefix}/${name}:${tag}" "${root}/services"
  docker push "${image_prefix}/${name}:${tag}"
done

helm upgrade --install platform "${root}/charts/platform" \
  --namespace platform \
  --values "${root}/charts/platform/values-${env_name}.yaml" \
  --values "${config}" \
  --set "imageTag=${tag}" \
  --wait \
  --timeout 15m
