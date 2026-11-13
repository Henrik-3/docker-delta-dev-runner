# Delta runner in Docker

Runs [Delta](https://delta.dev)'s `delta runner serve` headless in a container, so a server can act as a
[Personal Runner](https://delta.dev/docs/agents/cloud-runners).

Unofficial and not affiliated with Delta. The image contains Delta's own binaries, which fall under Delta's terms.

## Quick start

```sh
git clone https://github.com/Henrik-3/docker-delta-dev-runner && cd docker-delta-dev-runner
RUNNER_NAME=my-server docker compose up -d
docker compose logs -f
```

On the first start, the logs show a sign-in link (`https://dashboard.zed.dev/delta/device?code=…`). Open it in any
browser and approve it. When the logs say `Runner is online`, you're done: restarts and image updates sign in on
their own.

## Configuration

| | |
|---|---|
| `RUNNER_NAME` | Name shown in Delta's runner picker. Defaults to `docker-runner`. |
| `keyring_password` secret | Optional. Without it, a password is generated and stored on the keyring volume (see below). |

## How it works

Delta needs a Secret Service keyring for settings sync, which is where runner registrations live. Without one,
sign-in works but `runner serve` fails with "Settings sync is unavailable". The entrypoint therefore starts a D-Bus
session and an unlocked gnome-keyring before running `delta runner serve`.

Three volumes hold the state: `~/.config/delta`, `~/.local/share/delta` and `~/.local/share/keyrings` (the saved
session). The generated keyring password sits next to the keyring, so it protects the session no better than
Delta's own plaintext `credentials.json` fallback. To keep it off the volume, uncomment the `keyring_password`
secret in `compose.yaml`.

`docker stop` sends SIGINT (like Ctrl+C), which takes the runner offline cleanly. Remove old runners in Delta's
settings.

## You have to sign in again when

- the volumes are deleted (`docker compose down -v`),
- the keyring password changes (the container exits with `keyring not unlocked`; delete the keyring volume), or
- the session is revoked or expires (the container turns unhealthy and the logs show a new link).

## Image

`ghcr.io/henrik-3/delta-runner` is built for amd64 and arm64 by
[a workflow](.github/workflows/delta-runner-image.yml). The workflow checks for new stable Delta releases every 6
hours, builds and smoke-tests the image, and then pushes `:<delta-version>` and `:latest`. To build it yourself, run
`docker compose build`.
