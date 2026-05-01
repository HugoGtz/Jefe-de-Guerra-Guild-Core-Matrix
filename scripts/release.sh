#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOC="$ROOT/GuildCoreMatrix.toc"

cd "$ROOT"

get_toc_version() {
  sed -n 's/^## Version: //p' "$TOC" | head -1 | tr -d '\r'
}

apply_toc_version() {
  local new_ver="$1"
  local tmp
  tmp="$(mktemp)"
  sed "s/^## Version: .*/## Version: ${new_ver}/" "$TOC" > "$tmp"
  mv "$tmp" "$TOC"
}

toc_matches_head() {
  [[ -z "$(git status --porcelain -- "$TOC")" ]]
}

usage() {
  echo "usage: $0 [options] [patch | minor | major | set X.Y.Z]" >&2
  echo "  Default (not --tag-only): bump TOC → commit TOC → tag vX.Y.Z → push HEAD → push tag (needs clean tree)." >&2
  echo "  --no-push        same but stop before git push (local commit + tag only)." >&2
  echo "  --bump-only      only edit GuildCoreMatrix.toc (no git)." >&2
  echo "  --tag-only       tag current committed TOC on HEAD; default no push; use --push to publish." >&2
  echo "  --push           with --tag-only: push HEAD then tag" >&2
  echo "  --allow-dirty    with --tag-only: allow other dirty files; TOC must match HEAD" >&2
  exit 1
}

TAG_ONLY=0
BUMP_ONLY=0
KIND="patch"
SET_VER=""
USE_EXPLICIT_PUSH=0
WANT_PUSH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push)
      WANT_PUSH=1
      USE_EXPLICIT_PUSH=1
      shift
      ;;
    --no-push)
      WANT_PUSH=0
      USE_EXPLICIT_PUSH=1
      shift
      ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    --tag-only) TAG_ONLY=1; shift ;;
    --bump-only) BUMP_ONLY=1; shift ;;
    patch | minor | major) KIND="$1"; shift ;;
    set)
      SET_VER="${2:-}"
      if [[ -z "$SET_VER" ]]; then echo "ERROR: set requires X.Y.Z" >&2; exit 1; fi
      KIND="set"
      shift 2
      ;;
    -h | --help) usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

ALLOW_DIRTY="${ALLOW_DIRTY:-0}"

if [[ "$TAG_ONLY" -eq 1 && "$BUMP_ONLY" -eq 1 ]]; then
  echo "ERROR: use either --tag-only or --bump-only, not both." >&2
  exit 1
fi

DO_PUSH=0
if [[ "$TAG_ONLY" -eq 1 ]]; then
  if [[ "$USE_EXPLICIT_PUSH" -eq 0 ]]; then
    DO_PUSH=0
  else
    DO_PUSH=$WANT_PUSH
  fi
elif [[ "$BUMP_ONLY" -eq 1 ]]; then
  DO_PUSH=0
else
  if [[ "$USE_EXPLICIT_PUSH" -eq 0 ]]; then
    DO_PUSH=1
  else
    DO_PUSH=$WANT_PUSH
  fi
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: Not a git repository." >&2
  exit 1
fi

CURRENT="$(get_toc_version)"
if [[ -z "$CURRENT" ]]; then
  echo "ERROR: No ## Version in $TOC" >&2
  exit 1
fi

if [[ "$TAG_ONLY" -eq 1 ]]; then
  VERSION="$CURRENT"
  if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: ## Version must be MA.MI.PA (got: $VERSION)" >&2
    exit 1
  fi
  if ! toc_matches_head; then
    echo "ERROR: GuildCoreMatrix.toc is not committed at HEAD. Commit it, then tag." >&2
    exit 1
  fi
  TAG="v${VERSION}"
  if [[ "$ALLOW_DIRTY" -eq 0 ]]; then
    if [[ -n "$(git status --porcelain)" ]]; then
      echo "ERROR: Working tree not clean. Stash/commit other files or use --allow-dirty." >&2
      exit 1
    fi
  fi
  if git rev-parse "refs/tags/$TAG" >/dev/null 2>&1; then
    echo "ERROR: Tag $TAG already exists." >&2
    exit 1
  fi
  git tag -a "$TAG" -m "Release GuildCoreMatrix $VERSION"
  echo "Created annotated tag $TAG on $(git rev-parse --short HEAD)"
  if [[ "$DO_PUSH" -eq 1 ]]; then
    git push origin HEAD
    git push origin "$TAG"
    echo "Pushed HEAD then $TAG"
  else
    echo "Push when ready: git push origin HEAD && git push origin $TAG"
  fi
  exit 0
fi

compute_new_ver() {
  local cur="$1"
  local kind="$2"
  local set_v="$3"
  if [[ "$kind" == "set" ]]; then
    if [[ ! "$set_v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "ERROR: Version must be MA.MI.PA (got: $set_v)" >&2
      exit 1
    fi
    echo "$set_v"
    return
  fi
  if [[ ! "$cur" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "ERROR: Current ## Version must be MA.MI.PA (got: $cur)" >&2
    exit 1
  fi
  local ma="${BASH_REMATCH[1]}"
  local mi="${BASH_REMATCH[2]}"
  local pa="${BASH_REMATCH[3]}"
  case "$kind" in
    patch) pa=$((pa + 1)) ;;
    minor) mi=$((mi + 1)); pa=0 ;;
    major) ma=$((ma + 1)); mi=0; pa=0 ;;
  esac
  echo "${ma}.${mi}.${pa}"
}

NEW_VER="$(compute_new_ver "$CURRENT" "$KIND" "$SET_VER")"

if [[ "$NEW_VER" == "$CURRENT" ]]; then
  echo "Already at $NEW_VER (TOC unchanged)."
  exit 0
fi

TAG="v${NEW_VER}"

if [[ "$BUMP_ONLY" -eq 1 ]]; then
  apply_toc_version "$NEW_VER"
  echo "Bumped $CURRENT -> $NEW_VER ($TOC)"
  exit 0
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: Working tree must be clean before release (commit or stash everything)." >&2
  exit 1
fi

if git rev-parse "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "ERROR: Tag $TAG already exists." >&2
  exit 1
fi

apply_toc_version "$NEW_VER"
git add GuildCoreMatrix.toc
git commit -m "chore: release $NEW_VER"
git tag -a "$TAG" -m "Release GuildCoreMatrix $NEW_VER"
echo "Released $CURRENT -> $NEW_VER (commit + tag $TAG at $(git rev-parse --short HEAD))"

if [[ "$DO_PUSH" -eq 1 ]]; then
  git push origin HEAD
  git push origin "$TAG"
  echo "Pushed HEAD then $TAG"
else
  echo "Skipped push (passed --no-push). When ready: git push origin HEAD && git push origin $TAG"
fi
