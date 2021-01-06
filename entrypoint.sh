#!/usr/bin/env bash
# the entrypoint for the GitHub Action; this script lints everything possible~

# funcs
die() { echo "$1" >&2; exit "${2:-1}"; }

# check project root
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# vars
cfpath="./cf"

# check repository + setup vars
repo="$(basename "$PWD")" \
  || die "failed to get repository name"
[[ "$repo" == "linter" ]] && { cfpath="./testdata"; }

# check deps
deps=(docker)
[[ -d "$cfpath" ]] && { deps+=(aws sam); }
for dep in "${deps[@]}"; do
  hash "$dep" 2>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -ne 0 ]]; then
  [[ ${#missing[@]} -gt 1 ]] && { s="s"; }
  die "missing dep${s}: ${missing[*]}"
fi

# setup
errors=()

# lint cf + sam templates?
if [[ -d "$cfpath" ]]; then

  # check auth
  aws sts get-caller-identity &>/dev/null \
    || die "unable to connect to AWS; are you authed?"

  # lint cf templates
  mapfile -t files < <(find "$cfpath" -name '*.yml' -type f | sort)
  for file in "${files[@]}"; do
    echo "##[group]Linting $file"
    aws cloudformation validate-template --template-body "file://$file" \
      || { errors+=("cf|$file"); }
    echo "##[endgroup]"
  done

  # lint sam templates
  mapfile -t files < <(find "$cfpath" -name '*.yaml' -type f | sort)
  for file in "${files[@]}"; do
    echo "##[group]Linting $file"
    sam validate -t "$file" \
      || { errors+=("sam|$file"); }
    echo "##[endgroup]"
  done
fi

# lint Dockerfiles
mapfile -t files < <(find . -name '*Dockerfile*' -type f | sort)
for file in "${files[@]}"; do
  echo "##[group]Linting $file"
  docker run --rm -i hadolint/hadolint < "$file" \
    || { errors+=("Dockerfile|$file"); }
  echo "##[endgroup]"
done

# lint Bash
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

# lint Go files, using built Dockerfile.
mapfile -t files < <(find . -name '*.go' -type f | sort)
if [[ "${#files}" -ne 0 ]]; then
  for file in "${files[@]}"; do
    echo "##[group]Linting $file"
    docker run --rm \
      -w /app \
      -v "$PWD:/app" \
      linter \
      bash -c "revive -formatter friendly ./$file" \
      || { errors+=("go|$file"); }
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
      cf) errorsCF+=("$file") ;;
      sam) errorsSAM+=("$file") ;;
      go) errorsGo+=("$file") ;;
    esac
  done
  if [[ "${#errorsDockerfile[@]}" -ne 0 ]]; then
    s=""; [[ ${#errorsDockerfile[@]} -gt 1 ]] && { s="s"; }
    echo "${#errorsDockerfile[@]} Dockerfile$s found with issues."
  fi
  if [[ "${#errorsBash[@]}" -ne 0 ]]; then
    s=""; [[ ${#errorsBash[@]} -gt 1 ]] && { s="s"; }
    echo "${#errorsBash[@]} Bash script$s found with issues."
  fi
  if [[ "${#errorsCF[@]}" -ne 0 ]]; then
    s=""; [[ ${#errorsCF[@]} -gt 1 ]] && { s="s"; }
    echo "${#errorsCF[@]} CloudFormation template$s found with issues."
  fi
  if [[ "${#errorsSAM[@]}" -ne 0 ]]; then
    s=""; [[ ${#errorsSAM[@]} -gt 1 ]] && { s="s"; }
    echo "${#errorsSAM[@]} SAM template$s found with issues."
  fi
  if [[ "${#errorsGo[@]}" -ne 0 ]]; then
    s=""; [[ ${#errorsGo[@]} -gt 1 ]] && { s="s"; }
    echo "${#errorsGo[@]} Go file$s found with issues."
  fi
  exit 1
fi
