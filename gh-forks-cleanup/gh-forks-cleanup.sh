#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 --username USERNAME [--dry-run] [--keep-with-prs] [--max-repos N]"
    echo "  --username USERNAME  GitHub username (required)"
    echo "  --dry-run            List repositories that would be deleted without actually deleting them"
    echo "  --keep-with-prs      Keep forks that have open pull requests"
    echo "  --max-repos N        Maximum number of repositories to process (default: all)"
    echo "  --help               Display this help message"
    exit 1
}

# Initialize variables
username=""
dry_run=false
keep_with_prs=false
max_repos=0

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --username)
            username="$2"
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --keep-with-prs)
            keep_with_prs=true
            shift
            ;;
        --max-repos)
            max_repos="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown parameter: $1"
            usage
            ;;
    esac
done

# Check if username is provided
if [ -z "$username" ]; then
    echo "Error: GitHub username is required."
    usage
fi

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Please install it from https://cli.github.com/"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    echo "Please install it with your package manager (e.g., apt, brew)"
    exit 1
fi

# Check if gh is authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI."
    echo "Please run 'gh auth login' first."
    exit 1
fi

# Function to check for rate limiting
check_rate_limit() {
    local rate_info
    rate_info=$(gh api rate_limit 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to check rate limit."
        return 1
    fi
    
    local remaining
    remaining=$(echo "$rate_info" | jq '.resources.core.remaining')
    
    if [ "$remaining" -lt 10 ]; then
        local reset_time
        reset_time=$(echo "$rate_info" | jq '.resources.core.reset')
        local reset_date
        reset_date=$(date -d "@$reset_time" 2>/dev/null || date -r "$reset_time" 2>/dev/null)
        
        echo "Warning: GitHub API rate limit almost reached ($remaining requests remaining)."
        echo "Rate limit will reset at: $reset_date"
        
        if [ "$remaining" -lt 5 ]; then
            return 1
        fi
    fi
    
    return 0
}

# Get all repositories for the user and filter for forks
echo "Getting repository list for $username..."

# Use pagination to get all repositories if max_repos is 0
all_repos=()
page=1
per_page=100
total_fetched=0

while true; do
    # Check rate limit before making API call
    if ! check_rate_limit; then
        echo "Rate limit reached. Please try again later."
        exit 1
    fi
    
    # Fetch a page of repositories
    page_repos=$(gh api "users/$username/repos?page=$page&per_page=$per_page" \
  --jq '[.[] | select(.fork == true) | {name: .name, html_url: .html_url, isFork: .fork, isPrivate: .private, owner: {login: .owner.login}}]')

    # Check if we got an error or empty response
    if [ $? -ne 0 ] || [ "$(echo "$page_repos" | jq 'length')" -eq 0 ]; then
        break
    fi
    
    # Add to our collection
    all_repos+=("$page_repos")
    
    # Update counters
    count_on_page=$(echo "$page_repos" | jq 'length')
    total_fetched=$((total_fetched + count_on_page))
    
    # Check if we've reached the max or if this page wasn't full (meaning it's the last page)
    if [ "$max_repos" -gt 0 ] && [ "$total_fetched" -ge "$max_repos" ]; then
        break
    fi
    
    if [ "$count_on_page" -lt "$per_page" ]; then
        break
    fi
    
    # Move to next page
    page=$((page + 1))
    
    # Small delay to be nice to the API
    sleep 0.5
done

# Combine all pages and filter repos
if [ ${#all_repos[@]} -eq 0 ]; then
    echo "No repositories found for $username."
    exit 0
fi

# Combine all pages into a single JSON array
combined_repos=$(echo "${all_repos[@]}" | jq -s 'add')

# Filter repos to exclude private repos and org repos
filtered_repos=$(echo "$combined_repos" | jq "[.[] | select(.isPrivate == false and .owner.login == \"$username\")]")

# Apply max_repos limit if specified
if [ "$max_repos" -gt 0 ]; then
    filtered_repos=$(echo "$filtered_repos" | jq ".[0:$max_repos]")
fi

# Check if we got any repositories
if [ -z "$filtered_repos" ] || [ "$(echo "$filtered_repos" | jq length)" -eq 0 ]; then
    echo "No public, personal forked repositories found for $username."
    exit 0
fi

# Print count of filtered repos
repo_count=$(echo "$filtered_repos" | jq length)
echo "Found $repo_count public, personal forked repositories."

# Arrays to store repos
declare -a repos_to_delete_names
declare -a repos_to_delete_urls
declare -a repos_to_keep_names
declare -a repos_to_keep_urls
declare -a repos_with_errors_names
declare -a repos_with_errors_urls

# Process each fork
echo "Analyzing forked repositories..."
while read -r repo_info; do
    name=$(echo "$repo_info" | jq -r '.name')
    url=$(echo "$repo_info" | jq -r '.html_url')
    
    echo "Checking $name..."
    
    # Check rate limit before making API calls
    if ! check_rate_limit; then
        echo "Rate limit reached. Stopping analysis."
        break
    fi
    
    keep_repo=false
    error_occurred=false
    
    # Get commits by user to this repo (limit to 1 to save time)
    response=$(gh api "repos/$username/$name/commits?author=$username&per_page=1" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to check commits for $name."
        error_occurred=true
    elif [ "$(echo "$response" | jq 'length')" -gt 0 ]; then
        keep_repo=true
        echo "Keeping $name (found commits by $username)"
    fi
    
    # Check for open PRs if requested
    if [ "$keep_with_prs" = true ] && [ "$keep_repo" = false ] && [ "$error_occurred" = false ]; then
        # Get the parent repository info
        parent_info=$(gh api "repos/$username/$name" --jq '.parent.full_name' 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$parent_info" ]; then
            # Check for open PRs from this fork to the parent
            pr_info=$(gh api "repos/$parent_info/pulls?head=$username:$name&state=open" 2>/dev/null)
            if [ $? -eq 0 ] && [ "$(echo "$pr_info" | jq 'length')" -gt 0 ]; then
                keep_repo=true
                echo "Keeping $name (has open pull requests)"
            fi
        else
            echo "Warning: Could not determine parent repository for $name."
        fi
    fi
    
    # Add to appropriate array
    if [ "$error_occurred" = true ]; then
        repos_with_errors_names+=("$name")
        repos_with_errors_urls+=("$url")
    elif [ "$keep_repo" = true ]; then
        repos_to_keep_names+=("$name")
        repos_to_keep_urls+=("$url")
    else
        repos_to_delete_names+=("$name")
        repos_to_delete_urls+=("$url")
        echo "No commits or PRs found in $name, marking for deletion."
    fi
    
    # Small delay to be nice to the API
    sleep 0.5
    
done < <(echo "$filtered_repos" | jq -c '.[]')

# Print summary before deletion
total_forks=${#repos_to_delete_names[@]}
total_kept=${#repos_to_keep_names[@]}
total_errors=${#repos_with_errors_names[@]}
grand_total=$((total_forks + total_kept + total_errors))

echo "====== Summary ======"
echo "Total public personal forks analyzed: $grand_total"
echo "Forks with commits or PRs: $total_kept"
echo "Forks without commits or PRs: $total_forks"
if [ "$total_errors" -gt 0 ]; then
    echo "Forks with errors during analysis: $total_errors"
    echo "Repositories with errors (skipped):"
    for i in "${!repos_with_errors_names[@]}"; do
        echo "- ${repos_with_errors_names[$i]}: ${repos_with_errors_urls[$i]}"
    done
fi

# Delete repositories or show what would be deleted
if [ ${#repos_to_delete_names[@]} -gt 0 ]; then
    if [ "$dry_run" = true ]; then
        echo "The following repositories would be deleted (dry run):"
        for i in "${!repos_to_delete_names[@]}"; do
            echo "WOULD DELETE: ${repos_to_delete_names[$i]}: ${repos_to_delete_urls[$i]}"
        done
        echo "This was a dry run. No repositories were actually deleted."
    else
        echo "The following repositories will be deleted:"
        for i in "${!repos_to_delete_names[@]}"; do
            echo "- ${repos_to_delete_names[$i]}: ${repos_to_delete_urls[$i]}"
        done
        
        # Ask for confirmation
        read -p "Are you sure you want to delete these repositories? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation canceled."
            exit 0
        fi
        
        echo "Proceeding to delete ${#repos_to_delete_names[@]} repositories..."
        deleted_count=0
        failed_count=0
        for i in "${!repos_to_delete_names[@]}"; do
            repo="${repos_to_delete_names[$i]}"
            url="${repos_to_delete_urls[$i]}"
            echo "Deleting $repo ($url)..."
            if gh repo delete "$username/$repo" --yes; then
                echo "Successfully deleted $repo: $url"
                deleted_count=$((deleted_count + 1))
            else
                echo "Failed to delete $repo: $url"
                failed_count=$((failed_count + 1))
            fi
            
            # Small delay between deletions
            sleep 1
        done
        echo "Successfully deleted $deleted_count out of ${#repos_to_delete_names[@]} repositories."
        if [ "$failed_count" -gt 0 ]; then
            echo "Failed to delete $failed_count repositories."
        fi
    fi
else
    echo "No repositories found that need to be deleted."
fi

echo "Done!"