# Bitwarden CLI

Simple image for deploying bitwarden-cli.

This repository includes:
- GitHub Actions workflow that builds and publishes to GitHub Container Registry (GHCR) on pushes to `main` (and manual dispatch).
- A `.dockerignore` to keep the image lean.
- An `entrypoint.sh` that logs in, unlocks, syncs, and starts `bw serve`.
- A hardened `Dockerfile` using a non-root user and `tini` for clean signal handling.

## Runtime Configuration

Do **not** bake secrets into the image. Provide these environment variables at runtime (e.g. via Coolify, Docker Compose, or Kubernetes):

- `BW_HOST` — URL of your vaultwarden (or Bitwarden) server, e.g. `https://vault.example.com`
- `BW_CLIENTID`
- `BW_CLIENTSECRET`
- `BW_PASSWORD` — your master password (consider using a secret manager)

Optional: mount a volume to `/app/.config` for persistent CLI configuration/session state.

## Ports

The container exposes `8087` and serves Bitwarden CLI endpoints via `bw serve`.

## Deploying with Coolify

1. Ensure image exists in GHCR: `ghcr.io/<your-user-or-org>/bitwarden-cli:latest`.
2. In Coolify create a new container app using that image.
3. Set environment variables (`BW_HOST`, `BW_CLIENTID`, `BW_CLIENTSECRET`, `BW_PASSWORD`).
4. (Optional) Add a volume mapping for persistence: host path → `/app/.config`.
5. Configure health check to hit `http://localhost:8087/status`.
6. Deploy.

## CI Workflow Summary

- Trigger: push to `main` or manual.
- Tags published:
  - `ghcr.io/<owner>/bitwarden-cli:<git-sha>`
  - `ghcr.io/<owner>/bitwarden-cli:latest`
- Uses BuildKit + cache to speed subsequent builds.

## Local Testing

```bash
docker build -t ghcr.io/olsonbd/bitwarden-cli:dev .
docker run --rm -p 8087:8087 \
  -e BW_HOST=https://vault.example.com \
  -e BW_CLIENTID=YOUR_ID \
  -e BW_CLIENTSECRET=YOUR_SECRET \
  -e BW_PASSWORD='correct horse battery staple' \
  ghcr.io/olsonbd/bitwarden-cli:dev

curl http://localhost:8087/status
```
