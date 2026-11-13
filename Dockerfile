FROM debian:13-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl python3 tar git \
      dbus gnome-keyring libsecret-tools \
      libxcb-xkb1 \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash delta
USER delta
WORKDIR /home/delta
ENV PATH=/home/delta/.local/bin:$PATH \
    XDG_RUNTIME_DIR=/tmp/runtime-delta

# The installer always fetches the latest stable release. DELTA_VERSION busts the layer cache per release
# and fails the build if latest moved on in the meantime; "latest" skips the check (rebuild with --no-cache).
ARG DELTA_VERSION=latest
RUN curl -fsSL https://delta.dev/install.sh -o /tmp/delta-install.sh \
 && sh /tmp/delta-install.sh --non-interactive \
 && { [ "$DELTA_VERSION" = latest ] || delta --version | grep -qx "delta $DELTA_VERSION"; } \
 && rm /tmp/delta-install.sh \
 && mkdir -p .config/delta .local/share/delta .local/share/keyrings

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

VOLUME ["/home/delta/.config/delta", "/home/delta/.local/share/delta", "/home/delta/.local/share/keyrings"]
# Exits 1 when signed out (verified), e.g. after the token is revoked; reuses the running delta-app.
HEALTHCHECK --interval=5m --timeout=30s --start-period=10m CMD delta auth status >/dev/null || exit 1
# Ctrl+C is what deregisters the runner cleanly.
STOPSIGNAL SIGINT
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
