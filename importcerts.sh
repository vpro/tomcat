#!/bin/sh
set -eu

GLOBAL_BUNDLE="${GLOBAL_BUNDLE:-/tmp/global-bundle.pem}"
JAVA_CACERTS_PASSWORD="${JAVA_CACERTS_PASSWORD:-changeit}"

import_bundle() {
  bundle="$1"
  prefix="$2"

  if [ ! -f "$bundle" ]; then
    echo "Skipping missing bundle: $bundle"
    return
  fi

  tmpdir="$(mktemp -d)"
  awk -v outdir="$tmpdir" '
    /-----BEGIN CERTIFICATE-----/ { i++; file=sprintf("%s/cert-%03d.pem", outdir, i) }
    file != "" { print > file }
    /-----END CERTIFICATE-----/ { file="" }
  ' "$bundle"

  for f in "$tmpdir"/cert-*.pem; do
    [ -e "$f" ] || break

    cn="$(
      openssl x509 -in "$f" -noout -subject |
      sed -n 's/.*CN[[:space:]]*=[[:space:]]*//p' |
      head -n 1
    )"
    if [ -n "$cn" ]; then
      alias_name="$(printf '%s' "$cn" | tr ' /,:' '-----')"
    else
      alias_name="$(basename "$f" .pem)"
    fi

    alias_key="${prefix}-${alias_name}"
    echo "Importing $f as $alias_key"
    keytool -delete -cacerts -storepass "$JAVA_CACERTS_PASSWORD" -alias "$alias_key" >/dev/null 2>&1 || true
    keytool -importcert -noprompt -trustcacerts -cacerts \
      -storepass "$JAVA_CACERTS_PASSWORD" \
      -alias "$alias_key" \
      -file "$f"
  done

  rm -rf "$tmpdir"
}

import_bundle "$GLOBAL_BUNDLE" "rds"
