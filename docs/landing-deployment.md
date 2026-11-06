# Public landing deployment

Verified 2026-11-06. This describes the static website only, not the sensor API or mobile releases.

## Current serving path

`https://opennoisenet.moinsen.dev/` → existing Cloudflare Tunnel → `http://localhost:18768` on the existing Hetzner host → `opennoisenet-site` nginx container → static Next export.

- Container port 3000 is bound exclusively to `127.0.0.1:18768`.
- The stopped rollback container `opennoisenet-site-pre-store` retains the 4 November site.
- Current document root: `/home/udi/opennoisenet-store-20261106`, an exact copy of the previous static release plus the two store policy pages. The previous release directory is `/opt/opennoisenet-site/releases/20261104-story-r2`.
- nginx config: `/opt/opennoisenet-site/nginx.conf`, tracked source `landing/nginx.conf`.
- Running image: `nginx@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de`.
- Files/config mounted read-only; ephemeral nginx cache/run directories; 96 MB and 128-process limits; `unless-stopped` restart policy.
- No access log at this origin. Cloudflare's own handling and logs are separate.
- The Cloudflare tunnel is remote-managed. Editing a local cloudflared YAML does not change its routing. Only the OpenNoiseNet hostname was added; all existing routes were preserved.
- Credentials, tunnel backups and SSH connection details are intentionally not recorded here.

## Build and verify

In `landing`, use `npm ci`, `npm run lint`, `npm run type-check`, `npm test`, `npm run build`. For the custom domain, leave `NEXT_PUBLIC_BASE_PATH` unset. Serve `out` locally and check direct navigation to `/`, `/story/`, `/privacy/`, `/imprint/`, `/cookie-preferences/`, assets and a missing route. Review desktop and narrow mobile layouts and the consent choice before publishing.

Copy only the built `out` contents into a **new** dated release directory; never copy environment files, recordings or app databases. Verify it privately before switching the website container to that directory. Retain the preceding directory for rollback. The site needs no Node runtime on the server. `landing/Dockerfile` can build the same static export into an nginx image.

Check the container with `nginx -t`, its loopback HTTP response, restart count, and the public HTTPS response. Cloudflare can transform HTML (including email obfuscation), so validate content, links and assets rather than demanding an identical HTML hash. A Cloudflare challenge is not proof that the origin is broken, and an origin HTTP 200 is not proof of a successful public browser journey. Preserve both observations.

## Rollback

For future releases, point only the website container back to the preceding verified release directory or image. Do not restart the application stack. If reverting the initial 2026-11-04 domain routing, remove only the exact `opennoisenet.moinsen.dev` ingress entry after fetching the latest tunnel config; never restore an old whole-tunnel backup over unrelated changes. DNS and zone-wide security settings were not changed by this release.

Store robots can encounter a managed challenge on the custom domain. The store declarations therefore use the anonymously readable [app privacy notice](https://moinsen-dev.github.io/open_noisenet/app-privacy/) and [deletion entry point](https://moinsen-dev.github.io/open_noisenet/account-deletion/) on the existing official Pages mirror. The static site never receives deletion credentials.

## Separate GitHub Pages target

The existing workflow `.github/workflows/deploy-landing.yml` serves `https://moinsen-dev.github.io/open_noisenet/`. It explicitly sets `NEXT_PUBLIC_BASE_PATH=/open_noisenet`. Run it through `workflow_dispatch` or the existing `landing_v*` tag convention. A successful GitHub Pages run does not deploy the custom-domain container, and vice versa.
