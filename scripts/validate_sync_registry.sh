#!/usr/bin/env bash
set -euo pipefail

CSV_PATH="${1:-}"

if [[ -z "$CSV_PATH" ]]; then
  echo "usage: $0 <registry.csv>" >&2
  exit 1
fi

if [[ ! -f "$CSV_PATH" ]]; then
  echo "file not found: $CSV_PATH" >&2
  exit 1
fi

awk -F',' '
BEGIN {
  errors=0
}
NR==1 {
  expected="instance_name,environment,role,seq,base_url,bearer_token_alias,enabled,owner,last_health_check,status_note"
  if ($0 != expected) {
    print "ERROR: invalid header"
    print " expected: " expected
    print " actual  : " $0
    errors++
  }
  next
}
{
  line=NR
  instance=$1
  env=$2
  base=$5
  token_alias=$6
  enabled=tolower($7)

  gsub(/^ +| +$/, "", instance)
  gsub(/^ +| +$/, "", env)
  gsub(/^ +| +$/, "", base)
  gsub(/^ +| +$/, "", token_alias)
  gsub(/^ +| +$/, "", enabled)

  if (instance == "") {
    print "ERROR line " line ": instance_name is empty"
    errors++
  }
  if (env == "") {
    print "ERROR line " line ": environment is empty"
    errors++
  }
  if (base == "") {
    print "ERROR line " line ": base_url is empty"
    errors++
  }
  if (enabled != "true" && enabled != "false") {
    print "ERROR line " line ": enabled must be true/false"
    errors++
  }

  if (enabled == "true") {
    key_instance=env "|" instance
    key_base=env "|" base

    if (seen_instance[key_instance]++) {
      print "ERROR line " line ": duplicate enabled instance in same env -> " instance " (" env ")"
      errors++
    }
    if (seen_base[key_base]++) {
      print "ERROR line " line ": duplicate enabled base_url in same env -> " base " (" env ")"
      errors++
    }

    token_alias_by_env[env SUBSEP token_alias]++
    enabled_count_by_env[env]++
  }
}
END {
  for (k in token_alias_by_env) {
    split(k, parts, SUBSEP)
    env=parts[1]
    token=parts[2]
    token_count_by_env[env]++
  }

  for (env in enabled_count_by_env) {
    if (token_count_by_env[env] > 1) {
      print "WARN: environment " env " uses multiple bearer_token_alias values among enabled apps"
    }
  }

  if (errors > 0) {
    print "FAILED: " errors " error(s)"
    exit 1
  }

  print "OK: registry validation passed"
}
' "$CSV_PATH"
