#!/bin/bash
set -euo pipefail

REPOS_BASE="/repos"

# Read GITHUB_USERS and GIT_REPOS env variables into arrays
mapfile -t github_users < <(echo "$GITHUB_USERS" | sed '/^\s*$/d')
mapfile -t git_repos < <(echo "$GIT_REPOS" | sed '/^\s*$/d')

declare -A processed_repos

# Helper: parse repo URL into provider, username, repo_name
# Input example: https://github.com/user/reponame
parse_repo_url() {
    local url="$1"
    # Remove protocol
    url="${url#https://}"
    url="${url#http://}"
    # Remove trailing .git
    url="${url%.git}"
    # Extract provider (host), username, repo_name
    IFS='/' read -r provider username repo_name _ <<< "$url"
    echo "$provider" "$username" "$repo_name"
}

# 1. Process GIT_REPOS first
for repo_url in "${git_repos[@]}"; do
    read -r provider username repo_name < <(parse_repo_url "$repo_url")
    dest_dir="$REPOS_BASE/$provider/$username/$repo_name"

    echo "Processing GIT_REPO: $repo_url into $dest_dir"

    if [ -d "$dest_dir/.git" ]; then
        echo "Updating repo (git pull): $repo_url"
        git -C "$dest_dir" pull --quiet || echo "Warning: git pull failed for $repo_url"
    else
        echo "Cloning repo: $repo_url"
        mkdir -p "$(dirname "$dest_dir")"
        git clone --quiet "$repo_url" "$dest_dir" || echo "Warning: git clone failed for $repo_url"
    fi

    processed_repos["$repo_url"]=1
done

# 2. For each GitHub user, fetch repos and process
for user in "${github_users[@]}"; do
    echo "Fetching repos for GitHub user: $user"
    # Get repos JSON from GitHub API, filter for non-fork repos and extract html_url
    mapfile -t user_repos < <(
        wget -qO- "https://api.github.com/users/$user/repos?per_page=100" | python3 -c "
import sys, json
repos = json.load(sys.stdin)
for r in repos:
    if not r.get('fork', True):
        print(r.get('html_url', ''))
"
    )

    for repo_url in "${user_repos[@]}"; do
        # Skip repos already processed from GIT_REPOS (exact URL match)
        if [[ -n "${processed_repos["$repo_url"]+_}" ]]; then
            echo "Skipping already processed repo: $repo_url"
            continue
        fi

        read -r provider username repo_name < <(parse_repo_url "$repo_url")
        dest_dir="$REPOS_BASE/$provider/$username/$repo_name"

        echo "Processing GITHUB user repo: $repo_url into $dest_dir"

        if [ -d "$dest_dir/.git" ]; then
            echo "Updating repo (git pull): $repo_url"
            git -C "$dest_dir" pull --quiet || echo "Warning: git pull failed for $repo_url"
        else
            echo "Cloning repo: $repo_url"
            mkdir -p "$(dirname "$dest_dir")"
            git clone --quiet "$repo_url" "$dest_dir" || echo "Warning: git clone failed for $repo_url"
        fi

        processed_repos["$repo_url"]=1
    done
done
