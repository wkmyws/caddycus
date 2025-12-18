#!/bin/bash
# Check for new Caddy releases and plugin updates, trigger build if needed

set -euo pipefail

VERSION_FILE=".cache-version"
PLUGINS_FILE="plugins.txt"

# Get the latest Caddy release version from GitHub API
get_caddy_latest_version() {
    curl -s "https://api.github.com/repos/caddyserver/caddy/releases/latest" | \
        grep '"tag_name":' | \
        sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

# Get the latest commit SHA for a plugin repository
get_plugin_latest_commit() {
    local repo_url="$1"
    # Extract owner/repo from github.com/owner/repo
    local repo_path=$(echo "$repo_url" | sed -E 's|github\.com/||')
    
    # Get the default branch's latest commit SHA
    curl -s "https://api.github.com/repos/${repo_path}/commits/HEAD" | \
        grep '"sha":' | head -1 | \
        sed -E 's/.*"sha": *"([^"]+)".*/\1/' | \
        cut -c1-7  # Use short SHA (7 chars)
}

# Parse plugins.txt and get all plugin versions
get_all_plugin_versions() {
    local plugin_versions=""
    
    while IFS= read -r plugin || [ -n "$plugin" ]; do
        # Skip empty lines and comments
        case "$plugin" in
            ""|"#"*) continue ;;
        esac
        
        echo "  Checking plugin: $plugin" >&2
        local commit_sha=$(get_plugin_latest_commit "$plugin")
        
        if [ -n "$commit_sha" ]; then
            plugin_versions="${plugin_versions}${plugin}@${commit_sha}"$'\n'
            echo "    Latest commit: $commit_sha" >&2
        else
            echo "    Warning: Failed to get version for $plugin" >&2
        fi
    done < "$PLUGINS_FILE"
    
    printf '%s' "$plugin_versions"
}

# Generate version file content (caddy@version + each plugin@commit)
generate_version_content() {
    local caddy_version="$1"
    local plugin_versions="$2"
    
    # Format: caddy@version on first line, then each plugin@commit on separate lines
    printf "caddy@%s\n%s" "$caddy_version" "$plugin_versions"
}

# Get the currently built version fingerprint (hash of entire .cache-version file)
get_current_fingerprint() {
    if [ -f "$VERSION_FILE" ]; then
        # Calculate hash of the entire version file content
        cat "$VERSION_FILE" | sha256sum | cut -c1-16
    else
        echo ""
    fi
}

# Main logic
main() {
    echo "Checking for Caddy and plugin updates..."
    echo ""
    
    # Get Caddy version
    echo "Checking Caddy version..."
    CADDY_LATEST=$(get_caddy_latest_version)
    echo "  Latest Caddy: $CADDY_LATEST"
    echo ""
    
    if [ -z "$CADDY_LATEST" ]; then
        echo "Error: Failed to fetch Caddy version"
        exit 1
    fi
    
    # Get all plugin versions
    echo "Checking plugin versions..."
    PLUGIN_VERSIONS=$(get_all_plugin_versions)
    echo ""
    
    # Generate new version file content
    NEW_VERSION_CONTENT=$(generate_version_content "$CADDY_LATEST" "$PLUGIN_VERSIONS")
    NEW_FINGERPRINT=$(echo "$NEW_VERSION_CONTENT" | sha256sum | cut -c1-16)
    CURRENT_FINGERPRINT=$(get_current_fingerprint)
    
    echo "Current fingerprint: ${CURRENT_FINGERPRINT:-none}"
    echo "New fingerprint: $NEW_FINGERPRINT"
    echo ""
    
    if [ "$NEW_FINGERPRINT" != "$CURRENT_FINGERPRINT" ]; then
        echo "✓ Changes detected! Triggering build..."
        if [ -n "${GITHUB_OUTPUT:-}" ]; then
            echo "new_version=true" >> "$GITHUB_OUTPUT"
            echo "version=$CADDY_LATEST" >> "$GITHUB_OUTPUT"
            echo "fingerprint=$NEW_FINGERPRINT" >> "$GITHUB_OUTPUT"
        fi
    else
        echo "✓ Already up to date"
        if [ -n "${GITHUB_OUTPUT:-}" ]; then
            echo "new_version=false" >> "$GITHUB_OUTPUT"
            echo "version=$CADDY_LATEST" >> "$GITHUB_OUTPUT"
            echo "fingerprint=$NEW_FINGERPRINT" >> "$GITHUB_OUTPUT"
        fi
    fi
}

main "$@"
