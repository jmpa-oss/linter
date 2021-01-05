#!/usr/bin/env bash
# the entrypoint for the GitHub Action; this script lints everything possible~

# funcs
die() { echo "$1" >&2; exit "${2:-1}"; }

# check project root
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps
deps=(docker aws)
for dep in "${deps[@]}"; do
  hash "$dep" 2>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -ne 0 ]]; then
  [[ ${#missing[@]} -gt 1 ]] && { s="s"; }
  die "missing dep${s}: ${missing[*]}"
fi

# check auth
aws sts get-caller-identity &>/dev/null \
  || die "unable to connect to AWS; are you authed?"

# setup
errors=()

# lint Dockerfiles
mapfile -t files < <(find . -name '*Dockerfile*' -type f | sort)
for file in "${files[@]}"; do
  echo "##[group]Linting $file"
  docker run --rm -i hadolint/hadolint < "$file" \
    || { errors+=("Dockerfile|$file"); }
  echo "##[endgroup]"
done

# lint bash
mapfile -t files < <(find . -name '*.sh' -type f | sort)
for file in "${files[@]}"; do
  echo "##[group]Linting $file"
  docker run --rm \
    -w /app \
    -v "$PWD:/app" \
    koalaman/shellcheck "$file" \
    || { errors+=("bash|$file"); }
  echo "##[endgroup]"
done

# lint cf
if [[ -d ./cf ]]; then
  mapfile -t files < <(find ./cf -name '*.yml' -type f | sort)
  for file in "${files[@]}"; do
    echo "##[group]Linting $file"
    aws cloudformation validate-template --template-body "file://$file" \
      || { errors+=("cf|$file"); }
    echo "##[endgroup]"
  done
fi

# any errors?
if [[ "${#errors[@]}" -ne 0 ]]; then
  for error in "${errors[@]}"; do
    type=$(<<< "$error" cut -d'|' -f1)
    file=$(<<< "$error" cut -d'|' -f2)
    case $type in
      Dockerfile) errorsDockerfile+=("$file") ;;
      bash) errorsBash+=("$file") ;;
      cf) errorsCloudFormation+=("$file") ;;
    esac
  done
  if [[ "${#errorsDockerfile[@]}" -ne 0 ]]; then
    s=""; [[ ${#errorsDockerfile[@]} -gt 1 ]] && { s="s"; }
    echo "${#errorsDockerfile[@]} Dockerfile$s found with linting issues."

  fi
  if [[ "${#errorsBash[@]}" -ne 0 ]]; then
    s=""; [[ ${#errorsBash[@]} -gt 1 ]] && { s="s"; }
    echo "${#errorsBash[@]} bash script$s found with linting issues."
  fi
  if [[ "${#errorsCloudFormation[@]}" -ne 0 ]]; then
    s=""; [[ ${#errorsCloudFormation[@]} -gt 1 ]] && { s="s"; }
    echo "${#errorsCloudFormation[@]} CloudFormation template$s found with linting issues."
  fi
  exit 1
fi
