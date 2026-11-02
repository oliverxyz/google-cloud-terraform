#!/usr/bin/env bash
# End-to-end check of a running environment: the public API, the whole pipeline,
# ordering, the dead-letter path and network isolation.
# Usage: scripts/verify.sh <env>
set -uo pipefail

env_name="${1:?usage: verify.sh <env>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
project_id="$(sed -n 's/^project_id *= *"\(.*\)"/\1/p' "${root}/bootstrap/terraform.tfvars")"

failures=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1"; failures=$((failures + 1)); }
check() { if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1 (expected $3, got $2)"; fi; }

config="$(gcloud secrets versions access latest --secret "${env_name}-deploy-config" --project "${project_id}")"
value() { python3 -c "import json,sys;d=json.loads(sys.argv[1]);print(d$2)" "${config}"; }
hostname="$(value "" "['ingress']['hostname']")"
bucket="$(value "" "['bucket']")"
database_host="$(value "" "['database']['host']")"
base="https://${hostname}"

token="$(gcloud secrets versions access latest --secret "${env_name}-api-token" --project "${project_id}")"
# The token goes through a file descriptor, so it does not appear in the process list.
api() { curl -sS --max-time 30 -K <(printf 'header = "Authorization: Bearer %s"\n' "${token}") "$@"; }
post() { api -X POST -H 'Content-Type: application/json' -d "$2" "${base}$1"; }
field() { python3 -c "import json,sys;print(json.load(sys.stdin).get(sys.argv[1]))" "$1"; }

echo "--- waiting for HTTPS on ${hostname}, a new certificate takes a while"
ready=no
for _ in $(seq 1 180); do
  if [[ "$(curl -s -o /dev/null --max-time 10 -w '%{http_code}' "${base}/healthz")" == "200" ]]; then
    ready=yes
    break
  fi
  sleep 10
done
check "HTTPS answers with a valid certificate" "${ready}" yes
[[ "${ready}" == "yes" ]] || exit 1

check "request without a token is rejected" \
  "$(curl -s -o /dev/null --max-time 30 -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{}' "${base}/documents")" 401
http_code="$(curl -s -o /dev/null --max-time 10 -w '%{http_code}' "http://${hostname}/healthz")"
check "port 80 is not served" "${http_code}" 000

echo "--- pipeline and ordering"
document="$(post /documents '{"title":"verify","content":"first"}' | field id)"
post "/documents/${document}/revisions" '{"content":"second"}' >/dev/null
post "/documents/${document}/revisions" '{"content":"third"}' >/dev/null
processed=""
for _ in $(seq 1 30); do
  processed="$(api "${base}/documents/${document}" | field processed_revision)"
  [[ "${processed}" == "3" ]] && break
  sleep 5
done
check "all revisions are processed in order" "${processed}" 3
check "document status" "$(api "${base}/documents/${document}" | field status)" processed
check "one file per revision" \
  "$(gcloud storage ls "gs://${bucket}/documents/${document}/" --project "${project_id}" 2>/dev/null | wc -l)" 3

echo "--- dead-letter path, takes a few minutes"
poison="$(post /documents '{"title":"poison","content":"x","simulate_failure":true}' | field id)"
status=""
for _ in $(seq 1 72); do
  status="$(api "${base}/documents/${poison}" | field status)"
  [[ "${status}" == "failed" ]] && break
  sleep 5
done
check "failing message reaches the dead-letter handler" "${status}" failed

echo "--- report"
report="$(post /reports '{}' | field report_object)"
if gcloud storage ls "gs://${bucket}/${report}" --project "${project_id}" >/dev/null 2>&1; then
  pass "report file ${report}"
else
  fail "report file '${report}'"
fi

echo "--- network, from inside the worker Pod"
probe() {
  kubectl -n platform exec deploy/worker -- python -c "
import socket,sys
try:
    socket.create_connection((sys.argv[1], int(sys.argv[2])), 5).close(); print('open')
except OSError:
    print('closed')" "$1" "$2" </dev/null
}
check "database port 5432" "$(probe "${database_host}" 5432)" open
check "database port 3307" "$(probe "${database_host}" 3307)" closed
check "internet" "$(probe 1.1.1.1 443)" closed
check "reporter from worker" "$(probe reporter 8080)" closed

echo "--- rate limit"
limited=no
for _ in $(seq 1 60); do
  [[ "$(curl -s -o /dev/null --max-time 10 -w '%{http_code}' "${base}/documents/x")" == "429" ]] && limited=yes && break
done
check "burst of requests is limited" "${limited}" yes

echo
if ((failures)); then
  echo "RESULT: ${failures} check(s) failed"
  exit 1
fi
echo "RESULT: all checks passed"
