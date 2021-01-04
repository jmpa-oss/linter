#!/usr/bin/env bash
# cleans up the repository built off this template, when first created.

# funcs
die() { echo "$1" >&2; exit "${2:-1}"; }

# check project root
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps
deps=(aws curl)
for dep in "${deps[@]}"; do
  hash "$dep" 2>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -ne 0 ]]; then
  [[ ${#missing[@]} -gt 1 ]] && { s="s"; }
  die "missing dep${s}: ${missing[*]}"
fi

# retrieve variables
name="${GITHUB_REPOSITORY##*/}"
name="${name^^}" # uppercase
name="${name,,}" # lowercase

# retrieve GitHub token
token=$(aws ssm get-parameter --name "/tokens/github" \
--query "Parameter.Value" --output text --with-decryption) \
  || die "failed to retrieve GitHub token from paramstore"

# retrieve repository information
resp=$(curl -s "https://api.github.com/repos/jmpa-oss/$name" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: bearer $token") \
  || die "failed to retrieve $name repository info"
desc=$(<<< "$resp" jq -r '.description') \
  || die "failed to parse $name repository info"

# update + move files to their new destinations.
files=(
  .github/workflows/template-cleanup/README.md,./README.md
  .github/workflows/template-cleanup/action.yml,./action.yml
)
for file in "${files[@]}"; do
  src=$(<<< "$file" cut -d',' -f1)
  dest=$(<<< "$file" cut -d',' -f2)
  [[ "$src" == "$dest" ]] && { continue; } # skip files without destination paths

  # check file
  [[ -f "$src" ]] \
    || die "missing $src"

  # update file contents
  data="$(cat $src)" \
    || die "failed to read $src"
  data="${data//%ACTION%/$name}"      # replace repository name.
  data="${data//%DESCRIPTION%/$desc}" # update repository description.

  # overwrite file contents
  echo "$data" > "$dest" \
    || die "failed to update $dest with $src"
done

# remove template-specific files.
rm -rf \
  .github/workflows/template-cleanup.yml \
  .github/workflows/template-cleanup/ \
  ./bin/template-cleanup.sh \
  ./bin/update-templates.sh \
  || die "failed to remove template-specific files"