# Lab-32 — Conjur secrets in CI/CD (GitHub Actions via OIDC → authn-jwt)
**Closes JD gaps:** *Conjur ↔ GitHub Actions / CI-CD* + *DevSecOps*. **Status:** authored + YAML/policy/consumer validated locally; live run pending a real repo + reachable Conjur. **Ties to:** PJ15 Conjur (L4).

**Pattern proven:** a pipeline mints a short-lived **GitHub OIDC JWT**, exchanges it at **Conjur `authn-jwt`** for a short-lived access token, fetches the secret **at run time**, uses it, and proves **no secret is stored at rest** — and **no long-lived Conjur API key is kept as a GitHub secret**. This is the modern DevSecOps posture (workload identity, not shared static creds).

## Files
```
.github/workflows/conjur-secrets.yml   the pipeline (OIDC -> authn-jwt -> fetch -> use -> prove)
conjur/policy.yml                      Conjur policy: authn-jwt/github service, repo host, entitlement
conjur/bootstrap.sh                    admin script: load policy + set jwks/issuer/claim + seed secret
app/consume_secret.py                  demo consumer — uses the secret, never prints it
docker-compose.conjur.yml              local Conjur OSS to test against (ties to PJ15)
.gitignore                             blocks .env/keys/tokens from ever being committed
```

## ⚡ Golden Path
1. **Stand up Conjur** (or reuse PJ15). Local:
   ```bash
   export CONJUR_DATA_KEY="$(docker run --rm cyberark/conjur data-key generate)"
   docker compose -f docker-compose.conjur.yml up -d
   docker compose -f docker-compose.conjur.yml exec conjur conjurctl account create myorg   # capture admin API key
   ```
2. **Configure Conjur** (admin): `conjur/bootstrap.sh` loads `policy.yml`, sets the GitHub OIDC metadata
   (`jwks-uri`, `issuer`, `token-app-property=repository`), and seeds `github/db/password`.
3. **Wire the repo** — Settings ▸ Secrets and variables ▸ Actions ▸ **Variables** (non-secret config):
   `CONJUR_URL`, `CONJUR_ACCOUNT=myorg`, `CONJUR_AUTHN_JWT_SERVICE_ID=github`, `CONJUR_VARIABLE_ID=github/db/password`.
   Update the host annotation in `policy.yml` to your real `owner/repo`.
4. **Push** → the workflow runs on `main`/dispatch:
   OIDC JWT → `authn-jwt` token → `GET /secrets` → `app/consume_secret.py` → **no-secret-at-rest** proof step.
5. **Evidence** = the green run: the "Fetched secret from Conjur (masked)" line, the consumer's `sha256[:12]` fingerprint, and the final `OK: no hard-coded secrets` assertion — with **no** Conjur API key in GitHub Secrets.

## Why this is the strong answer (interview-ready)
- **Workload identity, not shared secrets:** GitHub OIDC + Conjur `authn-jwt` means no long-lived Conjur credential lives in GitHub. Rotating/revoking is policy-side.
- **Least privilege:** the repo host is entitled to exactly one variable (`github/db/password`) via `!permit`.
- **Defense in depth:** `::add-mask::` on token + secret, `.gitignore` blocks accidental commits, and a CI gate greps for hard-coded secrets and fails the build.
- **Portable:** swap the `authn-jwt` service_id/claims to cover **GitLab CI, Jenkins (OIDC), or Azure DevOps** — same policy shape, different issuer/claim. (That's how this one lab extends to the rest of the JD's CI list.)

## Local validation already done
`yaml.safe_load` parses the workflow (1 job / 5 steps / `id-token: write`) and compose; the Conjur policy parses (3 entries); `app/consume_secret.py` returns OK with a secret and fails cleanly without one; `bootstrap.sh` passes `bash -n`.

## To reach L3 (needs a real repo + Conjur)
Push to a GitHub repo with the Variables set and a reachable Conjur (local OSS or the PJ15 instance), run the workflow, and capture the green run + logs as evidence. Then clone the same policy for GitLab/Azure DevOps/Jenkins to close those JD rows too.

## Alternative (API-key) path
If OIDC isn't available, the official `cyberark/conjur-action@v2` fetches secrets using `CONJUR_AUTHN_LOGIN` + `CONJUR_AUTHN_API_KEY` stored as GitHub **Secrets**. It works, but keeps a long-lived credential in GitHub — prefer the OIDC/JWT path above.
