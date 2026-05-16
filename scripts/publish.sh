#!/usr/bin/env bash
# publish.sh — bump version, update CHANGELOG, tag, push, publish to pub.dev,
#              then create a new development branch ready for the next cycle.
#
# Usage:
#   ./scripts/publish.sh            # patch bump (2.2.0 → 2.2.1)
#   ./scripts/publish.sh minor      # minor bump (2.2.0 → 2.3.0)
#   ./scripts/publish.sh major      # major bump (2.2.0 → 3.0.0)
#   ./scripts/publish.sh 2.5.0      # explicit version

set -euo pipefail

# ── colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}▶ $*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
die()     { echo -e "${RED}✗ $*${RESET}" >&2; exit 1; }

# ── resolve repo root ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

PUBSPEC="$ROOT/pubspec.yaml"
CHANGELOG="$ROOT/CHANGELOG.md"

# ── pre-flight checks ─────────────────────────────────────────────────────────
info "Running pre-flight checks..."

command -v dart   >/dev/null 2>&1 || die "'dart' not found in PATH."
command -v flutter >/dev/null 2>&1 || die "'flutter' not found in PATH."
command -v git    >/dev/null 2>&1 || die "'git' not found in PATH."

[[ -f "$PUBSPEC"   ]] || die "pubspec.yaml not found at $ROOT"
[[ -f "$CHANGELOG" ]] || die "CHANGELOG.md not found at $ROOT"

# Must be on main branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "$CURRENT_BRANCH" == "main" ]] || die "Must be on 'main' branch (currently on '$CURRENT_BRANCH')."

# Working tree must be clean
if ! git diff-index --quiet HEAD --; then
  die "Working tree has uncommitted changes. Commit or stash them first."
fi

success "Pre-flight checks passed."

# ── read current version ──────────────────────────────────────────────────────
CURRENT_VERSION="$(grep '^version:' "$PUBSPEC" | awk '{print $2}')"
[[ -n "$CURRENT_VERSION" ]] || die "Could not read version from pubspec.yaml."

IFS='.' read -r MAJ MIN PAT <<< "$CURRENT_VERSION"

# ── compute new version ───────────────────────────────────────────────────────
BUMP="${1:-patch}"
case "$BUMP" in
  major)      NEW_VERSION="$((MAJ + 1)).0.0" ;;
  minor)      NEW_VERSION="${MAJ}.$((MIN + 1)).0" ;;
  patch)      NEW_VERSION="${MAJ}.${MIN}.$((PAT + 1))" ;;
  [0-9]*.*.*) NEW_VERSION="$BUMP" ;;              # explicit e.g. 2.5.0
  *)          die "Unknown bump type '$BUMP'. Use: major | minor | patch | x.y.z" ;;
esac

echo
echo -e "${BOLD}  Current version : ${YELLOW}${CURRENT_VERSION}${RESET}"
echo -e "${BOLD}  New version     : ${GREEN}${NEW_VERSION}${RESET}"
echo
read -rp "$(echo -e "${BOLD}Proceed? [y/N]: ${RESET}")" CONFIRM
[[ "${CONFIRM,,}" == "y" ]] || { warn "Aborted."; exit 0; }

# ── run quality gates ─────────────────────────────────────────────────────────
info "Running quality gates..."

echo "  dart analyze lib/ ..."
dart analyze lib/ || die "dart analyze reported issues. Fix them before publishing."

echo "  flutter test ..."
flutter test --no-pub || die "Tests failed. Fix them before publishing."

success "All quality gates passed."

# ── collect changelog entry ───────────────────────────────────────────────────
echo
echo -e "${BOLD}Enter CHANGELOG entry for v${NEW_VERSION}${RESET}"
echo -e "${CYAN}(Describe what changed. Press CTRL-D when done.)${RESET}"
echo

CHANGELOG_BODY=""
while IFS= read -r line; do
  CHANGELOG_BODY+="${line}"$'\n'
done

[[ -n "$CHANGELOG_BODY" ]] || { warn "Empty changelog — aborting."; exit 1; }

TODAY="$(date '+%Y-%m-%d')"

# ── bump version in pubspec.yaml ──────────────────────────────────────────────
info "Bumping version in pubspec.yaml: $CURRENT_VERSION → $NEW_VERSION"
# Use perl for portable in-place edit (works on both macOS and Linux)
perl -i -pe "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"
success "pubspec.yaml updated."

# ── prepend CHANGELOG entry ───────────────────────────────────────────────────
info "Updating CHANGELOG.md..."
ENTRY="## [${NEW_VERSION}] - ${TODAY}"$'\n\n'"${CHANGELOG_BODY}"
# Insert new entry after the first line (the "# Changelog" header)
perl -i -0pe "s/(# Changelog\n\nAll notable.*?\n\n)/\$1${ENTRY}\n/" "$CHANGELOG"
success "CHANGELOG.md updated."

# ── commit the version bump ───────────────────────────────────────────────────
info "Committing version bump..."
git add "$PUBSPEC" "$CHANGELOG"
git commit -m "Prepare ${NEW_VERSION} release

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
success "Version bump committed."

# ── create and push git tag ───────────────────────────────────────────────────
TAG="v${NEW_VERSION}"
info "Creating tag ${TAG}..."
git tag -a "$TAG" -m "Release ${TAG}"
success "Tag ${TAG} created."

info "Pushing main and tag to origin..."
git push origin main
git push origin "$TAG"
success "Pushed to origin."

# ── dry-run publish first ─────────────────────────────────────────────────────
info "Running 'dart pub publish --dry-run'..."
dart pub publish --dry-run || die "Dry-run failed. Fix issues and re-run."
success "Dry-run passed."

# ── publish to pub.dev ────────────────────────────────────────────────────────
echo
warn "About to publish ${NEW_VERSION} to pub.dev. This cannot be undone."
read -rp "$(echo -e "${BOLD}Publish now? [y/N]: ${RESET}")" PUB_CONFIRM
[[ "${PUB_CONFIRM,,}" == "y" ]] || { warn "Publish skipped. Tag and commit are already pushed."; exit 0; }

info "Publishing to pub.dev..."
dart pub publish --force
success "Published flutter_state_migrator ${NEW_VERSION} to pub.dev!"

# ── create next development branch ───────────────────────────────────────────
IFS='.' read -r N_MAJ N_MIN N_PAT <<< "$NEW_VERSION"
NEXT_DEV_VERSION="${N_MAJ}.${N_MIN}.$((N_PAT + 1))-dev"
DEV_BRANCH="dev/v${N_MAJ}.${N_MIN}.$((N_PAT + 1))"

info "Creating development branch: ${DEV_BRANCH}..."
git checkout -b "$DEV_BRANCH"

# Stamp pubspec with -dev suffix so it's clear this is post-release
perl -i -pe "s/^version: .*/version: $NEXT_DEV_VERSION/" "$PUBSPEC"
git add "$PUBSPEC"
git commit -m "Begin ${NEXT_DEV_VERSION} development cycle

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git push -u origin "$DEV_BRANCH"

success "Development branch '${DEV_BRANCH}' created and pushed."

echo
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}${BOLD}  Released: flutter_state_migrator ${NEW_VERSION}${RESET}"
echo -e "${GREEN}  Tag     : ${TAG}${RESET}"
echo -e "${GREEN}  Next dev: ${DEV_BRANCH} (${NEXT_DEV_VERSION})${RESET}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
