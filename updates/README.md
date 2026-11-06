# Update feeds

The Pages workflow builds `beta/appcast.xml` from the highest-build-number published beta release. It verifies the exact GitHub download URL, archive length, SHA-256 checksum, and Ed25519 signature against the pinned public key before deployment. Draft releases are excluded. Publishing a release triggers deployment; the workflow can also be dispatched manually on main.

Stable releases reserve `/appcast.xml`; no stable feed is published yet. Beta builds embed `/beta/appcast.xml` and check approximately hourly while running, with user-controlled installation. Beta.5 omitted the feed and key, so users must manually install the first update-enabled beta once.

Generated feeds are not committed. Run `INIGO_OPENSSL=/opt/homebrew/opt/openssl@3/bin/openssl python3 scripts/prepare-beta-feed.py` on macOS with OpenSSL 3, or use the Ubuntu Pages workflow.
