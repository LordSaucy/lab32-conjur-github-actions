"""Demo consumer: uses the Conjur-provided secret without ever printing its value.

In a real job this is where you'd open a DB connection, call an API, etc. Here we
only prove the secret arrived, then emit a non-reversible fingerprint so the run is
auditable without leaking the value.
"""
from __future__ import annotations

import hashlib
import os
import sys


def main() -> int:
    secret = os.environ.get("DB_PASSWORD")
    if not secret:
        print("ERROR: DB_PASSWORD not in environment — Conjur fetch failed or step order wrong.",
              file=sys.stderr)
        return 1
    fingerprint = hashlib.sha256(secret.encode()).hexdigest()[:12]
    print(f"OK: received secret of length {len(secret)} "
          f"(sha256[:12]={fingerprint}); value not printed.")
    # ... use `secret` here (DB connect / API call) ...
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
