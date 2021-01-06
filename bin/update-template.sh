#!/usr/bin/env bash
# updates a repository built from the base template, with the latest changes.

# funcs
die() { echo "$1" >&2; exit "${2:-1}"; }

# check project root
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check remote has been setup
[[ $(git remote show template 2>/dev/null) ]] || {
  git remote add template "https://github.com/jmpa-oss/actions-template.git" \
    || die "failed to add remote template"
}

# update remote
git fetch template \
  || die "failed to fetch remote changes"

# check for any changes
remotebranch="template/master"
branch=$(git branch --show-current) \
  || die "failed to get current checked out branch"
files=($(git diff --name-only "$branch" "$remotebranch")) \
  || die "failed to get remote changed files list for $remotebranch"
[[ ${#files[@]} -eq 0 ]] && \
  die "no files found to update for $remotebranch, skipping merge to $branch" 0

# merge changes
git merge "$remotebranch" --allow-unrelated-histories \
  -m "update $branch with latest changes from $remotebranch" \
  || die "failed to merge $remotebranch changes to $branch"
