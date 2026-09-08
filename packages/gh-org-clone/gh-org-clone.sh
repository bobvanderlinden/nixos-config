usage() {
  cat <<'EOF'
Usage: gh-org-clone <organization>

Clones every non-archived repository in the organization into the current
working directory. Fetches existing repositories instead.
EOF
}

if [[ $# -eq 1 && ( "$1" == "--help" || "$1" == "-h" ) ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

organization="$1"

while IFS=$'\t' read -r repository_name repository_url; do
  if [[ -d "$repository_name" ]]; then
    if ! git -C "$repository_name" rev-parse --git-dir > /dev/null 2>&1; then
      printf 'Cannot fetch %s: %s is not a Git repository\n' "$repository_name" "$repository_name" >&2
      exit 1
    fi

    printf 'Fetching %s\n' "$repository_name"
    git -C "$repository_name" fetch --prune
  elif [[ -e "$repository_name" ]]; then
    printf 'Cannot clone %s: %s already exists and is not a directory\n' "$repository_name" "$repository_name" >&2
    exit 1
  else
    printf 'Cloning %s\n' "$repository_name"
    git clone "$repository_url" "$repository_name"
  fi
done < <(
  gh api --paginate "orgs/$organization/repos?type=all&per_page=100" \
    --jq '.[] | select(.archived | not) | [.name, .ssh_url] | @tsv'
)
