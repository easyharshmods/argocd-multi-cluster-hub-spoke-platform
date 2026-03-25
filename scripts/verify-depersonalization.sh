#!/bin/bash
set -euo pipefail

# Verify no personal/assignment references remain in the codebase

echo "==================================================================="
echo "Verifying Depersonalization"
echo "==================================================================="

ERRORS=0

check_pattern() {
  local pattern="$1"
  local description="$2"
  local matches

  matches=$(grep -ri "${pattern}" --include="*.md" --include="*.yaml" --include="*.yml" --include="*.tf" --include="*.sh" --include="*.py" --exclude-dir=.git --exclude-dir=.terraform -l . 2>/dev/null || true)

  if [ -n "${matches}" ]; then
    echo "FAIL: Found '${description}' in:"
    echo "${matches}" | sed 's/^/  /'
    ERRORS=$((ERRORS + 1))
  else
    echo "PASS: No '${description}' references found"
  fi
}

check_pattern "Hydrosat" "company name (Hydrosat)"
check_pattern "easyharshmods" "personal domain (easyharshmods)"
check_pattern "technical challenge" "interview context (technical challenge)"
check_pattern "assignment" "interview context (assignment)"
check_pattern "interview" "interview context (interview)"

echo ""
echo "==================================================================="
if [ ${ERRORS} -eq 0 ]; then
  echo "All depersonalization checks passed!"
else
  echo "FAIL: ${ERRORS} pattern(s) still found. Fix before committing."
fi
echo "==================================================================="

exit ${ERRORS}
