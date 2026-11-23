# Changelog

Each entry is one version of this template. Breaking changes come first.

## 1.4.0 (2026-11-23)

- First release of the template: Resume Matcher v1.4.0 (`ghcr.io/srbhr/resume-matcher:1.4.0`, pinned by digest) with a Caddy 2.11.9 password front.
- All data (SQLite database, settings, uploads and the encryption key) on a Railway volume at `/app/backend/data`.
- PDF export needs about 1 GB of memory. On a service under 700 MB it fails with an error and the rest of the app keeps running (Railway Free/Trial plans have 0.5 GB).
