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
hostname="$(value "" "['ingress']['services']['api']['hostname']")"
web_hostname="$(value "" "['ingress']['services']['web']['hostname']")"
bucket="$(value "" "['bucket']")"
database_host="$(value "" "['database']['host']")"
base="https://${hostname}"
web="https://${web_hostname}"

token="$(gcloud secrets versions access latest --secret "${env_name}-api-token" --project "${project_id}")"
# The token goes through a file descriptor, so it does not appear in the process list.
api() { curl -sS --max-time 30 -K <(printf 'header = "Authorization: Bearer %s"\n' "${token}") "$@"; }
post() { api -X POST -H 'Content-Type: application/json' -d "$2" "${base}$1"; }
# Prints nothing for a response that is not JSON, the check that follows reports the failure.
field() {
  python3 -c "
import json,sys
try:
    print(json.load(sys.stdin).get(sys.argv[1]))
except ValueError:
    pass" "$1"
}

# A new certificate reaches the load balancer proxies one by one, so a single good answer
# proves little: the next request may still get a TLS handshake failure.
wait_for_https() {
  local url="$1" streak=0
  echo "--- waiting for HTTPS on ${url}, a new certificate takes a while"
  for _ in $(seq 1 600); do
    if [[ "$(curl -s -o /dev/null --max-time 10 -w '%{http_code}' "${url}/healthz")" == "200" ]]; then
      streak=$((streak + 1))
    else
      streak=0
    fi
    if ((streak >= 20)); then
      echo yes
      return
    fi
    sleep 3
  done
  echo no
}
ready="$(wait_for_https "${base}" | tail -n 1)"
check "API answers over HTTPS with a valid certificate" "${ready}" yes
web_ready="$(wait_for_https "${web}" | tail -n 1)"
check "web answers over HTTPS with a valid certificate" "${web_ready}" yes
[[ "${ready}" == "yes" && "${web_ready}" == "yes" ]] || exit 1

check "request without a token is rejected" \
  "$(curl -s -o /dev/null --max-time 30 -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{}' "${base}/documents")" 401
http_code="$(curl -s -o /dev/null --max-time 10 -w '%{http_code}' "http://${hostname}/healthz")"
check "port 80 is not served" "${http_code}" 000

echo "--- pipeline and ordering"
document="$(post /documents '{"title":"verify","content":"first"}' | field id)"
if [[ -z "${document}" ]]; then
  fail "document is created"
  echo "RESULT: stopped, the API does not accept documents"
  exit 1
fi
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
check "web from worker" "$(probe web 8080)" closed

echo "--- web interface"
web_probe() {
  kubectl -n platform exec deploy/web -- python -c "
import socket,sys
try:
    socket.create_connection((sys.argv[1], int(sys.argv[2])), 5).close(); print('open')
except OSError:
    print('closed')" "$1" "$2" </dev/null
}
check "page is served" "$(curl -s -o /dev/null --max-time 10 -w '%{http_code}' "${web}/")" 200
check "page has a content security policy" \
  "$(curl -sI --max-time 10 "${web}/" | grep -ci '^content-security-policy:')" 1
check "all services are up" "$(curl -s --max-time 10 "${web}/status" | python3 -c "
import json,sys
print(all(s['status'] == 'up' for s in json.load(sys.stdin)['services']))")" True
check "request through web without a token is rejected" \
  "$(curl -s -o /dev/null --max-time 30 -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{}' "${web}/api/documents")" 401
web_document="$(curl -sS --max-time 30 -K <(printf 'header = "Authorization: Bearer %s"\n' "${token}") \
  -X POST -H 'Content-Type: application/json' -d '{"title":"web","content":"through web"}' "${web}/api/documents" | field id)"
if [[ -n "${web_document}" && "${web_document}" != "None" ]]; then
  pass "request through web with a token"
else
  fail "request through web with a token"
fi
check "web cannot reach the database" "$(web_probe "${database_host}" 5432)" closed
check "web cannot reach the internet" "$(web_probe 1.1.1.1 443)" closed
check "port 80 on web is not served" \
  "$(curl -s -o /dev/null --max-time 10 -w '%{http_code}' "http://${web_hostname}/")" 000

echo "--- rate limit"
# Requests go in parallel: one at a time they are too slow to exhaust the limit of several Pods.
codes="$(seq 1 300 | xargs -P 30 -I{} curl -s -o /dev/null --max-time 10 -w '%{http_code}\n' "${base}/documents/x")"
echo "responses: $(sort <<<"${codes}" | uniq -c | awk '{printf "%s x%s  ", $2, $1}')"
limited=no
grep -qx 429 <<<"${codes}" && limited=yes
check "burst of requests is limited" "${limited}" yes

echo
if ((failures)); then
  echo "RESULT: ${failures} check(s) failed"
  exit 1
fi
echo "RESULT: all checks passed"
