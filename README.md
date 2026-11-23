[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/resume-matcher?utm_medium=integration&utm_source=button&utm_campaign=resume-matcher)

# Deploy and Host Resume Matcher on Railway

Resume Matcher is an open-source AI resume builder. You upload your resume once, paste a job description, and it tailors the resume to that job: it matches keywords, rewrites weak lines without inventing facts, scores the result for ATS systems, writes a cover letter and exports a PDF. It works with OpenAI, Anthropic, Gemini, OpenRouter, DeepSeek, Groq or any OpenAI-compatible API.

## About Hosting Resume Matcher

This template runs the official Resume Matcher 1.4.0 image (pinned by digest) as one Railway service. Inside it, the Python API and the Next.js web app listen only on the container's loopback, and a small Caddy front on Railway's public port asks for a username and password, because Resume Matcher has no login of its own and anyone who reaches it could spend your LLM key. The password is generated for you on deploy. Your resumes, jobs, settings and the app's encryption key live in SQLite on a Railway volume, so they survive redeploys and restarts. You only bring an LLM API key.

## Common Use Cases

* Tailor one master resume to each job you apply for, with a keyword match and an ATS score
* Write a one-page cover letter grounded in the job description and your real experience
* Keep up to five master resumes for different career tracks and export clean PDFs

## Dependencies for Resume Matcher Hosting

* An LLM API key (OpenAI by default; Anthropic, Gemini, OpenRouter, DeepSeek, Groq or any OpenAI-compatible endpoint also work)
* A Railway volume for the SQLite database and settings (created by the template)

### Deployment Dependencies

* Resume Matcher source and docs: https://github.com/srbhr/Resume-Matcher
* Release notes for 1.4.0: https://github.com/srbhr/Resume-Matcher/releases/tag/v1.4.0
* Template source (Dockerfile, start script, changelog): https://github.com/aalfath/resume-matcher-railway-template
* Get an OpenAI key: https://platform.openai.com/api-keys

### Implementation Details

**Service:** one service, `Resume Matcher`, built from the template repo. It holds the API, the web app and the password front. Volume: `/app/backend/data`.

**After deploy:**

1. Open the service's Railway URL and sign in as `admin` with the password in the service's `AUTH_PASSWORD` variable (Variables tab).
2. Upload your resume (PDF or DOCX), paste a job description and tailor it.
3. To change provider or model later, use the app's Settings page, or set `LLM_PROVIDER`, `LLM_MODEL` and `LLM_API_BASE` (for an OpenAI-compatible server, for example `https://openrouter.ai/api/v1`).

**Variables:**

* `LLM_API_KEY` (required): your provider's API key. For OpenAI, create one at platform.openai.com/api-keys.
* `LLM_PROVIDER`: `openai` (default), `anthropic`, `gemini`, `openrouter`, `deepseek`, `groq`, `ollama` or `openai_compatible`.
* `LLM_MODEL`: defaults to `gpt-5-nano-2025-08-07`, OpenAI's low-cost model and the app's own default.
* `LLM_API_BASE`: leave empty unless you use a custom OpenAI-compatible endpoint.
* `AUTH_USERNAME` / `AUTH_PASSWORD`: the sign-in for the whole app. The password is generated on deploy.

**Memory:** everything runs in 0.5 GB (Railway Free and Trial) except PDF export, which starts a headless Chromium and needs about 1 GB. On 0.5 GB a PDF export fails with an error while the rest of the app keeps running; on a plan with 1 GB or more it works.

**Not included:** the optional PostgreSQL backend (SQLite on the volume is upstream's default and is enough for one person), the "Claude Code" and "ChatGPT plan" providers (they need a local CLI or a loopback sign-in that can't run on a server) and the MCP server (stdio only upstream).

**Updates:** when a new Resume Matcher release is tested, the template repo's `main` gets a new pinned version and a `CHANGELOG.md` entry, and Railway shows you an update notice. Back up the volume before you apply it.

## Why Deploy Resume Matcher on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Resume Matcher on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->

## How this template is built

* `Dockerfile`: `FROM ghcr.io/srbhr/resume-matcher:1.4.0@sha256:ae84bc6f…` plus the Caddy 2.11.9 binary (also pinned by digest).
* `railway-start.sh`: hands the volume to the app user, refuses to start without a password of 12+ characters, starts the API, the web app and Caddy, and exits non-zero if any of them stops so Railway's restart policy brings it back.
* `Caddyfile`: basic auth for everything except `/healthz` (Railway's health check, which answers only when the API and the web app are both up).
* `pdf-memcheck.sh`, `chrome-headless-shell`, `playwright-driver-node`: wrap the image's Playwright driver and headless Chromium (used only for PDF export) with small-memory flags and a memory check. PDF export needs about 1 GB; on a smaller service they refuse to start, so the export fails with an error instead of getting the whole app OOM-killed. Set `CHROMIUM_MIN_MEMORY_MB=0` to skip the check.
* No `railway.json`: the health check (`/healthz`, 300 s) and restart policy (on failure, 10 retries) are set in the template itself.

See `CHANGELOG.md` for what changed in each version. Resume Matcher itself is licensed Apache-2.0 by its authors.
