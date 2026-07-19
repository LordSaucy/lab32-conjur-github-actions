#!/usr/bin/env bash
# Lab-32 bootstrap: load policy + configure the GitHub authn-jwt service + seed the secret.
# Run as a Conjur admin (the `conjur` CLI already logged in). Idempotent-ish.
set -euo pipefail

: "${CONJUR_ACCOUNT:?set CONJUR_ACCOUNT (e.g. myorg)}"
REPO="${GH_REPO:-myorg/myrepo}"   # owner/repo that the workflow runs in

echo "==> loading policy under root"
conjur policy load -b root -f conjur/policy.yml

echo "==> configuring the github authn-jwt authenticator"
conjur variable set -i conjur/authn-jwt/github/jwks-uri \
  -v "https://token.actions.githubusercontent.com/.well-known/jwks"
conjur variable set -i conjur/authn-jwt/github/issuer \
  -v "https://token.actions.githubusercontent.com"
conjur variable set -i conjur/authn-jwt/github/token-app-property \
  -v "repository"

echo "==> seeding the demo secret (rotate anytime by re-running this line)"
conjur variable set -i github/db/password -v "$(openssl rand -base64 24)"

cat <<EOF

==> DONE. Remaining server-side step (once):
    Add the authenticator to the Conjur server allow-list and restart:
      CONJUR_AUTHENTICATORS="authn,authn-jwt/github"
    (docker-compose.conjur.yml already sets this for the local OSS test.)

==> Then set these GitHub repo Variables (Settings > Secrets and variables > Actions > Variables):
      CONJUR_URL                 = <your Conjur URL>
      CONJUR_ACCOUNT             = ${CONJUR_ACCOUNT}
      CONJUR_AUTHN_JWT_SERVICE_ID = github
      CONJUR_VARIABLE_ID         = github/db/password
    (host annotation in policy.yml must match this repo: ${REPO})
EOF
