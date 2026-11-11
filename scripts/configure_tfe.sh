#!/usr/bin/env bash
# Creates the first (admin) user and the organization "test" in a new Terraform Enterprise.
# Run this ONCE, from your workstation or the client VM, after TFE is healthy behind the load balancer.
#
#   ./configure_tfe.sh <fqdn> <email> <admin user> <admin password>
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 <fqdn> <email> <admin user> <admin password>" >&2
  exit 1
fi

FQDN="$1"
EMAIL="$2"
ADMIN_USER="$3"
ADMIN_PASSWORD="$4"
ORG="test"

command -v jq > /dev/null || { echo "jq is required" >&2; exit 1; }

echo "Waiting for https://$FQDN/api/v1/health/readiness"
until curl -sS -o /dev/null -f --max-time 10 "https://$FQDN/api/v1/health/readiness"; do
  echo "TFE is not available yet, waiting..."
  sleep 15
done

echo "Retrieving the initial admin creation token"
IACT=$(curl -sS -f "https://$FQDN/admin/retrieve-iact")

echo "Creating the admin user $ADMIN_USER"
RESPONSE=$(curl -sS -f -X POST \
  --header "Content-Type: application/json" \
  --data "$(jq -n --arg u "$ADMIN_USER" --arg e "$EMAIL" --arg p "$ADMIN_PASSWORD" '{username: $u, email: $e, password: $p}')" \
  "https://$FQDN/admin/initial-admin-user?token=$IACT")

TOKEN=$(echo "$RESPONSE" | jq -er .token)

echo "Creating the organization $ORG"
curl -sS -f -X POST \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --data "$(jq -n --arg n "$ORG" --arg e "$EMAIL" '{data: {type: "organizations", attributes: {name: $n, email: $e}}}')" \
  "https://$FQDN/api/v2/organizations" > /dev/null

echo
echo "Done. Log in at https://$FQDN as $ADMIN_USER"
echo "API token of the admin user (store it safely, it is not shown again):"
echo "$TOKEN"
