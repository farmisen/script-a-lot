# GitHub Forks Cleanup

A bash script to help you clean up unused GitHub forks. This script identifies forked repositories that you haven't contributed to and helps you delete them to reduce clutter in your GitHub account.

## Purpose

Over time, developers accumulate many GitHub forks that they never end up contributing to. These unused forks clutter your repository list and make it harder to find the repositories you actually care about.

This script:

1. Identifies all your public forked repositories.
2. Checks if you've made any commits to them.
3. Optionally checks if you have any open pull requests.
4. Helps you delete the forks you haven't contributed to.

## Dependencies

The script requires the following tools:

- [GitHub CLI (gh)](https://cli.github.com/) - For GitHub API access.
- [jq](https://stedolan.github.io/jq/) - For JSON processing.
- Bash shell (version 4.0 or later).

## Installation

1. **Download the script:**

   ```bash
   curl -O https://raw.githubusercontent.com/farmisen/gh-forks-cleanup/main/gh-forks-cleanup.sh
   ```

2. **Make it executable:**

   ```bash
   chmod +x gh-forks-cleanup.sh
   ```

3. **Ensure you have the GitHub CLI installed and authenticated:**

   ```bash
   # Install GitHub CLI (example for macOS with Homebrew)
   brew install gh

   # Authenticate with GitHub
   gh auth login

   # Add delete_repo scope (required for deleting repositories)
   gh auth refresh -h github.com -s delete_repo
   ```

4. **Ensure you have jq installed:**

   ```bash
   # Example for macOS with Homebrew
   brew install jq

   # Example for Ubuntu/Debian
   sudo apt-get install jq
   ```

## Usage

### Basic Usage

Run the script with your GitHub username:

```bash
./gh-forks-cleanup.sh --username YOUR_GITHUB_USERNAME
```

This will:

- Find all your public forked repositories.
- Check if you've made any commits to them.
- Prompt you to confirm deletion of unused forks.
- Delete the repositories you confirm.

### Options

```bash
Usage: ./gh-forks-cleanup.sh --username USERNAME [--dry-run] [--keep-with-prs] [--max-repos N]

  --username USERNAME  GitHub username (required).
  --dry-run            List repositories that would be deleted without actually deleting them.
  --keep-with-prs      Keep forks that have open pull requests.
  --max-repos N        Maximum number of repositories to process (default: all).
  --help               Display this help message.
```

### Examples

#### Dry Run (No Deletions)

To see what would be deleted without actually deleting anything:

```bash
./gh-forks-cleanup.sh --username YOUR_GITHUB_USERNAME --dry-run
```

#### Keep Forks with Open Pull Requests

To keep forks that have open pull requests to the parent repository:

```bash
./gh-forks-cleanup.sh --username YOUR_GITHUB_USERNAME --keep-with-prs
```

#### Limit the Number of Repositories Processed

To process only a specific number of repositories (useful for testing):

```bash
./gh-forks-cleanup.sh --username YOUR_GITHUB_USERNAME --max-repos 10
```

## Troubleshooting

### Authentication Issues

If you see an error like:

```
This API operation needs the "delete_repo" scope. To request it, run: gh auth refresh -h github.com -s delete_repo
```

Run the suggested command to add the necessary permission scope:

```bash
gh auth refresh -h github.com -s delete_repo
```

### Rate Limiting

If you hit GitHub API rate limits, the script will pause and inform you. You can:

- Wait until the rate limit resets (the script will tell you when).
- Use the `--max-repos` option to process fewer repositories at a time.

### Permission Errors

If you're getting permission errors when trying to delete repositories:

1. Ensure you're authenticated with GitHub CLI:
   ```bash
   gh auth status
   ```
2. Make sure you have the `delete_repo` scope:
   ```bash
   gh auth refresh -h github.com -s delete_repo
   ```
3. Verify you're the owner of the repositories you're trying to delete.

### JSON Parsing Errors

If you see errors related to `jq` or JSON parsing:

1. Make sure `jq` is installed:
   ```bash
   jq --version
   ```
2. Check if your GitHub API responses are being rate-limited or returning errors.

## Caution

⚠️ **WARNING:** This script permanently deletes repositories. Use the `--dry-run` option first to see what would be deleted.
