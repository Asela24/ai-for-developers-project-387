#!/usr/bin/env bash
# Scenario verification, run by .github/workflows/verify.yml in a CI job that
# holds no model secret and shares nothing with the session that wrote the
# change.
#
# 1. Proves which commit is under test: `git rev-parse HEAD` must equal the PR
#    head SHA.
# 2. Reads the agreed spec named in the PR body (`Спецификация: #N`) and takes
#    the main and adjacent scenarios from its "## Verification Scenarios"
#    section (Playwright test titles).
# 3. Head: both scenarios must pass, with Playwright traces recorded.
# 4. Base, for fix/feat PRs: the head's e2e tests run against the base app.
#    The main scenario must fail there (the test detects the bug or the
#    missing behaviour). For a fix the adjacent scenario must pass on both.
#
# Everything lands in $EVIDENCE_DIR (SHA, result, logs, traces), which the
# workflow uploads as an Actions artifact named after the head SHA.
#
# Env: HEAD_SHA BASE_SHA PR_NUMBER PR_TITLE PR_BODY REPO GH_TOKEN EVIDENCE_DIR
set -euo pipefail

ev="${EVIDENCE_DIR:?}"
mkdir -p "$ev"
summary="$ev/result.md"
verdict=pass
rows=""

finish() {
  {
    echo "# Проверка сценариев PR #$PR_NUMBER"
    echo
    echo "- **Head SHA (git rev-parse HEAD):** \`$actual_sha\`"
    echo "- **Base SHA:** \`$BASE_SHA\`"
    echo "- **Спецификация:** ${spec:+#}${spec:-нет}"
    echo "- **Основной сценарий:** ${main:-—}"
    echo "- **Соседний сценарий:** ${adjacent:-—}"
    echo "- **Итог:** $1"
    if [ -n "$rows" ]; then
      echo
      echo "| Версия | Сценарий | Ожидание | Результат |"
      echo "| --- | --- | --- | --- |"
      printf '%b' "$rows"
    fi
    echo
    echo "Перед мержем сверьте Head SHA с текущим head PR. После нового push этот артефакт описывает прежнюю версию."
  } >"$summary"
  printf '%s\n' "$actual_sha" >"$ev/sha.txt"
  printf '%s\n' "$1" >"$ev/verdict.txt"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then cat "$summary" >>"$GITHUB_STEP_SUMMARY"; fi
  cat "$summary"
}

actual_sha=$(git rev-parse HEAD)
start_ref=$(git symbolic-ref -q --short HEAD || echo "$actual_sha")
echo "git rev-parse HEAD: $actual_sha"
if [ "$actual_sha" != "$HEAD_SHA" ]; then
  echo "::error::Checked out $actual_sha, but the PR head is $HEAD_SHA."
  finish "fail: проверен не тот коммит"
  exit 1
fi

# The field must start its own line ("**Спецификация:** #9", "- Спецификация: #9"),
# so prose that mentions the word elsewhere in the body is not picked up.
field='^[-*[:space:]]*Спецификация:[*[:space:]]*'
body=$(printf '%s\n' "$PR_BODY" | tr -d '\r')
spec=$(printf '%s\n' "$body" | grep -oE "$field#[0-9]+" | grep -oE '[0-9]+$' | head -1 || true)
main=""
adjacent=""
if [ -z "$spec" ]; then
  if printf '%s\n' "$body" | grep -qE "${field}нет"; then
    finish "not applicable: в PR указано «Спецификация: нет»"
    exit 0
  fi
  echo "::error::PR body names no spec. Fill «Спецификация: #N» (or «нет» for docs/CI changes)."
  finish "fail: в PR не указана спецификация"
  exit 1
fi

spec_body=$(gh issue view "$spec" --repo "$REPO" --json body --jq .body | tr -d '\r')
scenarios=$(printf '%s\n' "$spec_body" | sed -n '/^## Verification Scenarios/,/^## /p')
main=$(printf '%s\n' "$scenarios" | sed -nE 's/^- Main: `(.+)`.*$/\1/p' | head -1)
adjacent=$(printf '%s\n' "$scenarios" | sed -nE 's/^- Adjacent: `(.+)`.*$/\1/p' | head -1)
if [ -z "$main" ] || [ -z "$adjacent" ]; then
  echo "::error::Spec #$spec has no '## Verification Scenarios' with '- Main: \`…\`' and '- Adjacent: \`…\`'."
  finish "fail: в спецификации #$spec не выбраны сценарии"
  exit 1
fi

# Playwright --grep takes a regex; match the title literally.
escape() { printf '%s' "$1" | sed 's/[][\.*^$?+(){}|/]/\\&/g'; }

# run <label> <title> <expect: pass|fail>
run() {
  local label=$1 title=$2 expect=$3 got
  if (cd apps/web && pnpm exec playwright test --trace on --reporter=list \
    --output "$ev/$label" --grep "$(escape "$title")") >"$ev/$label.log" 2>&1; then
    got=pass
  else
    got=fail
  fi
  if grep -q "No tests found" "$ev/$label.log"; then
    echo "::error::No e2e test titled «$title» ($label)."
    got="not found"
  fi
  local mark="✅"
  if [ "$got" != "$expect" ]; then
    mark="❌"
    verdict=fail
  fi
  rows+="| ${label%%-*} | $title | $expect | $mark $got |\n"
}

run head-main "$main" pass
run head-adjacent "$adjacent" pass

kind=$(printf '%s' "$PR_TITLE" | sed -nE 's/^(fix|feat)(\([^)]*\))?!?:.*/\1/p')
if [ -n "$kind" ]; then
  # Base app, head tests: does the new test catch the old behaviour?
  git checkout -q "$BASE_SHA"
  git checkout -q "$HEAD_SHA" -- apps/web/e2e apps/web/playwright.config.ts
  pnpm install --frozen-lockfile >"$ev/base-install.log" 2>&1
  run base-main "$main" fail
  if [ "$kind" = fix ]; then
    run base-adjacent "$adjacent" pass
  fi
  # Back to where the run started (a branch locally, the head SHA on CI).
  git checkout -q -f "$start_ref"
fi

if [ "$verdict" = pass ]; then
  finish "pass"
else
  finish "fail"
  exit 1
fi
