# Resume Matcher on Railway: the official Resume Matcher image, pinned by version
# and digest, plus a pinned Caddy binary that puts a password in front of the app
# (Resume Matcher has no login of its own).
# Upstream: https://github.com/srbhr/Resume-Matcher (release v1.4.0)
# Update: bump the tag and digest below, add a CHANGELOG.md entry, merge to main.
FROM caddy:2.11.9@sha256:4851e54a46b206517c574821bb5cc67f170d2156041e9fbc4c9193b45e84a75b AS caddy

FROM ghcr.io/srbhr/resume-matcher:1.4.0@sha256:ae84bc6f14fefb83d7ee1fcd0d527a5e09ae4ec5082f2d5f277647623c7f5d57

# Start as root only to hand the Railway volume to the image's user (appuser,
# uid 1000), then drop privileges (see railway-start.sh).
USER root
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --chmod=0644 Caddyfile /etc/resume-matcher-railway/Caddyfile
COPY --chmod=0755 railway-start.sh /usr/local/bin/railway-start.sh
COPY --chmod=0755 pdf-memcheck.sh /usr/local/lib/resume-matcher-railway/pdf-memcheck.sh
COPY --chmod=0755 chrome-headless-shell playwright-driver-node /tmp/
# PDF export: put a memory check (and small-memory flags) in front of Playwright's
# Node driver and its headless Chromium.
RUN chmod 0755 /etc/resume-matcher-railway && caddy version \
 && d="$(dirname /ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell)" \
 && mv "$d/chrome-headless-shell" "$d/chrome-headless-shell.real" \
 && mv /tmp/chrome-headless-shell "$d/chrome-headless-shell" \
 && n="$(python -c 'import os,playwright;print(os.path.join(os.path.dirname(playwright.__file__),"driver"))')" \
 && mv "$n/node" "$n/node.real" \
 && mv /tmp/playwright-driver-node "$n/node" \
 && "$n/node.real" --version && sh -n "$n/node" && sh -n "$d/chrome-headless-shell"

ENV PORT=8080

# No VOLUME here: Railway rejects it. The template attaches a Railway volume at
# /app/backend/data (SQLite database, settings, uploads and the encryption key).
EXPOSE 8080
HEALTHCHECK NONE
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
CMD []
