#!/bin/sh
set -eu

KEYRING_PASSWORD_FILE=${KEYRING_PASSWORD_FILE:-/run/secrets/keyring_password}
if [ ! -s "$KEYRING_PASSWORD_FILE" ]; then
  # No secret mounted: generate one and keep it next to the keyring. That protects the session no better than
  # Delta's own plaintext credentials.json fallback; mount a keyring_password secret to keep it off the volume.
  KEYRING_PASSWORD_FILE=$HOME/.local/share/keyrings/.password
  [ -s "$KEYRING_PASSWORD_FILE" ] || (umask 077; head -c 24 /dev/urandom | base64 > "$KEYRING_PASSWORD_FILE")
fi

# Session bus started by hand (not dbus-run-session) so delta can be exec'd and get signals directly.
mkdir -p -m 700 "$XDG_RUNTIME_DIR"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
dbus-daemon --session --address="$DBUS_SESSION_BUS_ADDRESS" --fork --nopidfile

# --login creates the "login" collection on first run and unlocks it afterwards. Trailing newline stripped
# so `echo pass > file` and `echo -n pass > file` give the same keyring password.
tr -d '\n' < "$KEYRING_PASSWORD_FILE" | gnome-keyring-daemon --login --components=secrets >/dev/null

keyring_unlocked() {
  dbus-send --session --print-reply --dest=org.freedesktop.secrets \
    /org/freedesktop/secrets/aliases/default org.freedesktop.DBus.Properties.Get \
    string:org.freedesktop.Secret.Collection string:Locked 2>/dev/null | grep -q 'boolean false'
}
i=0
until keyring_unlocked; do
  i=$((i + 1))
  [ "$i" -lt 20 ] || { echo "entrypoint: keyring not unlocked (password differs from the one the persisted keyring was created with?)" >&2; exit 1; }
  sleep 0.5
done

# Signed out (first start, or token revoked): runner serve prints an approval link and the session lands in the keyring.
exec delta runner serve --name "${RUNNER_NAME:-$(hostname)}" "$@"
