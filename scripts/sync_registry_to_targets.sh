#!/usr/bin/env bash
set -euo pipefail

CSV_PATH="${1:-}"
SELF_INSTANCE="${2:-}"

if [[ -z "$CSV_PATH" ]]; then
  echo "usage: $0 <registry.csv> [self_instance_name]" >&2
  exit 1
fi

if [[ ! -f "$CSV_PATH" ]]; then
  echo "file not found: $CSV_PATH" >&2
  exit 1
fi

# Output newline-separated /webhook/voc endpoints for enabled apps.
# CSV columns:
# instance_name,environment,role,seq,base_url,bearer_token_alias,enabled,...
awk -F',' -v self="$SELF_INSTANCE" '
NR==1 { next }
{
  instance=$1
  base=$5
  enabled=$7

  gsub(/^ +| +$/, "", instance)
  gsub(/^ +| +$/, "", base)
  gsub(/^ +| +$/, "", enabled)

  if (tolower(enabled) != "true") next
  if (self != "" && instance == self) next

  if (base ~ /\/webhook\/voc$/) {
    print base
  } else if (base ~ /\/$/) {
    print base "webhook/voc"
  } else {
    print base "/webhook/voc"
  }
}
' "$CSV_PATH"
