#!/usr/bin/env bash
# Creates an environment from nothing: infrastructure, deployer access, application.
# The application is deployed by GitHub Actions from main. DEPLOY_LOCAL=1 deploys the
# current checkout from this machine instead.
# Usage: scripts/up.sh <env> [terraform apply arguments]
set -euo pipefail

env_name="${1:?usage: up.sh <env> [terraform apply arguments]}"
shift
root="$(cd "$(dirname "$0")/.." && pwd)"
project_id="$(sed -n 's/^project_id *= *"\(.*\)"/\1/p' "${root}/bootstrap/terraform.tfvars")"
region="$(sed -n 's/^region *= *"\(.*\)"/\1/p' "${root}/bootstrap/terraform.tfvars")"

cd "${root}/envs/${env_name}"
terraform init -input=false
terraform apply "$@"

gcloud container clusters get-credentials "${env_name}-gke" \
  --location "${region}" --project "${project_id}" --dns-endpoint

# The deployer account can connect to any cluster of the project. What it may do is
# granted here, in this cluster and namespace only.
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: platform
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployer
  namespace: platform
rules:
  - apiGroups:
      - ""
      - apps
      - gateway.networking.k8s.io
      - networking.gke.io
      - networking.k8s.io
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployer
  namespace: platform
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: deployer
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: deployer-${env_name}@${project_id}.iam.gserviceaccount.com
EOF

if [[ "${DEPLOY_LOCAL:-0}" == "1" ]]; then
  "${root}/scripts/deploy.sh" "${env_name}"
else
  gh workflow run deploy.yml --ref main -f "environment=${env_name}"
  # The run is not listed immediately after it is requested.
  sleep 10
  run_id="$(gh run list --workflow deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
  gh run watch "${run_id}" --exit-status
fi
