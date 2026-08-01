#!/usr/bin/env bash
set -euo pipefail

last=${!#}
should_fail=false
if [[ -n ${FAKE_FAIL_TARGET:-} && $last == "$FAKE_FAIL_TARGET" ]]; then
  should_fail=true
fi
if [[ -n ${FAKE_FAIL_BASENAME:-} && ${last##*/} == "$FAKE_FAIL_BASENAME" ]]; then
  should_fail=true
fi
if [[ $should_fail == true && ! -e $FAKE_FAIL_MARKER ]]; then
  : >"$FAKE_FAIL_MARKER"
  exit 1
fi
exec "$REAL_MV" "$@"
