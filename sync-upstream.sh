#!/usr/bin/env bash
#
# Sync this fork with the upstream project (dazedcat19/FMD2) and bring the
# result into the branch you are working on.
#
# It does the three steps in order:
#   1. update the fork's master on GitHub from its parent  (gh repo sync)
#   2. fast-forward the local master to that
#   3. merge master into the current branch
#
# Nothing here rewrites history and nothing is pushed to your branch; step 3
# leaves a merge commit for you to review and push yourself. If the merge
# conflicts the script stops with the conflicted files listed and leaves the
# merge in progress so you can resolve it.
#
# Usage:  ./sync-upstream.sh [--fetch-only]
#           --fetch-only   do steps 1 and 2, then just report what upstream
#                          changed; do not touch the current branch
#
set -euo pipefail

UPSTREAM_URL="https://github.com/dazedcat19/FMD2.git"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

FETCH_ONLY=0
[[ "${1:-}" == "--fetch-only" ]] && FETCH_ONLY=1

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

if [[ "$BRANCH" == "master" ]]; then
  echo "error: you are on master. Switch to your working branch first;" >&2
  echo "       master is kept as a clean mirror of upstream." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "error: working tree has uncommitted changes:" >&2
  git status --short --untracked-files=no | sed 's/^/       /' >&2
  echo "       commit or stash them first (md.lpi debug flags count too)." >&2
  exit 1
fi

# --- remote ------------------------------------------------------------------
if ! git remote get-url upstream >/dev/null 2>&1; then
  echo ">> adding upstream remote  $UPSTREAM_URL"
  git remote add upstream "$UPSTREAM_URL"
fi

# --- 1. sync the fork on GitHub ----------------------------------------------
# Doing this through GitHub (rather than pushing master ourselves) keeps the
# fork's "N commits behind" state honest and needs no local upstream history.
FORK="$(git remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
if command -v gh >/dev/null 2>&1; then
  echo ">> syncing fork $FORK master from upstream"
  gh repo sync "$FORK" --branch master
else
  echo ">> gh not found, syncing master locally instead"
  git fetch upstream --no-tags
  git push origin "upstream/master:refs/heads/master"
fi

# --- 2. fast-forward the local master ----------------------------------------
echo ">> fetching"
git fetch origin --no-tags --quiet
git fetch upstream --no-tags --quiet

OLD_MASTER="$(git rev-parse master)"
if ! git merge-base --is-ancestor master origin/master; then
  echo "error: local master has commits that origin/master does not." >&2
  echo "       master must stay a clean mirror of upstream. Move those" >&2
  echo "       commits to a branch and reset master to origin/master." >&2
  exit 1
fi
git update-ref refs/heads/master origin/master
NEW_MASTER="$(git rev-parse master)"

if [[ "$OLD_MASTER" == "$NEW_MASTER" ]]; then
  echo ">> master already up to date at $(git log --oneline -1 master)"
else
  COUNT="$(git rev-list --count "$OLD_MASTER..$NEW_MASTER")"
  echo ">> master advanced $COUNT commit(s) to $(git log --oneline -1 master)"
  echo
  echo "   changed outside lua/ (these are the ones that can affect the port):"
  git diff --stat "$OLD_MASTER" "$NEW_MASTER" -- ':!lua' | sed 's/^/     /'
  echo
  echo "   lua modules touched: $(git diff --name-only "$OLD_MASTER" "$NEW_MASTER" -- lua | wc -l)"
fi

# The in-app module updater pulls lua/ straight from upstream's master, so any
# local change under lua/ is temporary -- it survives only until upstream next
# touches that file. Point it out rather than let it surprise you later.
LOCAL_LUA="$(git diff --name-only master.."$BRANCH" -- lua)"
if [[ -n "$LOCAL_LUA" ]]; then
  echo
  echo ">> note: $BRANCH carries local changes under lua/:"
  echo "$LOCAL_LUA" | sed 's/^/     /'
  echo "   the in-app module updater re-downloads lua/ from upstream master,"
  echo "   so these get overwritten when upstream next changes those files."
  echo "   Send them upstream to make them stick."
fi

if [[ "$FETCH_ONLY" == "1" ]]; then
  echo
  echo ">> --fetch-only, leaving $BRANCH alone"
  exit 0
fi

# --- 3. merge into the working branch ----------------------------------------
if git merge-base --is-ancestor master "$BRANCH"; then
  echo
  echo ">> $BRANCH already contains master, nothing to merge"
  exit 0
fi

echo
echo ">> merging master into $BRANCH"
if ! git merge --no-ff --no-edit master; then
  echo
  echo "!! merge conflicts, left in progress. Conflicted files:" >&2
  git diff --name-only --diff-filter=U | sed 's/^/     /' >&2
  echo "   resolve, 'git add' them, then 'git commit'." >&2
  echo "   or back out with 'git merge --abort'." >&2
  exit 1
fi

cat <<EOF

>> merged. Before pushing:
     rebuild   lazbuild --build-mode=Linux64 --widgetset=gtk2 mangadownloader/md.lpi
     then run it -- a clean textual merge does not mean upstream's changes and
     the port's fixes still agree at runtime.
EOF
