# gitbackup

A lightweight Bash script to back up Git repositories - 

## Features

- Clone and update any Git repository by URL
- Automatically discover and back up all non-fork repositories of one or more GitHub users (via the GitHub API, no need for a PAT)
- Deduplication: repos listed explicitly in `GIT_REPOS` are not cloned twice even if they also appear in a GitHub user's repo list
- Mirrors are stored in a structured directory hierarchy: `<base>/<provider>/<username>/<repo>`
- Docker Compose setup for unattended periodic backups (runs every 2 hours by default)
- No external dependencies beyond `bash`, `git`, `python3`, and `wget`

## Directory Structure

Backups are stored under `/repos` (configurable) with the following layout:
```
/repos/
└── github.com/
    └── <username>/
        └── <reponame>/   ← standard git clone (non-bare)
```

## Configuration

The script is driven by two environment variables:

| Variable       | Description |
|----------------|-------------|
| `GIT_REPOS`    | Newline-separated list of Git repository URLs to back up |
| `GITHUB_USERS` | Newline-separated list of GitHub usernames — all non-fork repos for each user will be backed up |

At least one should be set.

## Usage

### Standalone
```bash
export GIT_REPOS="
https://github.com/youruser/repo1.git
https://github.com/youruser/repo2.git
"

export GITHUB_USERS="
youruser
anotheruser
"

bash gitbackup.bash
```

Backups will be stored under `/repos` by default. You can change the base path by editing the `REPOS_BASE` variable at the top of `gitbackup.bash`.

### With Docker Compose

Edit `docker-compose.yaml` to configure your repositories and users:
```yaml
environment:
  GIT_REPOS: |
    https://github.com/youruser/repo1.git
    https://github.com/youruser/repo2.git
  GITHUB_USERS: |
    youruser
    anotheruser
volumes:
  - ./gitbackup.bash:/gitbackup.bash:ro
  - ./repos:/repos
```

Then start the container:
```bash
docker compose up -d
```

The container will run the backup script every 2 hours and restart automatically unless stopped manually.

## How It Works

1. Repos listed in `GIT_REPOS` are processed first: cloned if not present, or updated via `git pull` if they already exist.
2. For each username in `GITHUB_USERS`, the GitHub API is queried to retrieve all non-fork repositories. Each repo is then cloned or updated, skipping any already handled in step 1.
3. All repos are tracked in a deduplication map to avoid redundant operations.



## License

[GPL-3.0](LICENSE)
