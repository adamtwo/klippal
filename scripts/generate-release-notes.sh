#!/bin/bash
# Generate release notes using Claude API
# Usage: ./generate-release-notes.sh <output_file>
# Requires: ANTHROPIC_API_KEY environment variable

set -e

OUTPUT_FILE="${1:-release-notes-content.md}"

# Get commits since last release
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -n "$LAST_TAG" ]; then
    echo "Getting commits since $LAST_TAG..."
    COMMITS=$(git log ${LAST_TAG}..HEAD --pretty=format:"%s" --no-merges | grep -v "Generated with Claude Code" || true)
else
    echo "No previous tag found, using recent commits..."
    COMMITS=$(git log --pretty=format:"%s" --no-merges -20 | grep -v "Generated with Claude Code" || true)
fi

if [ -z "$COMMITS" ]; then
    echo "No commits found"
    cat > "$OUTPUT_FILE" << 'EOF'
## Functionality

- No user-facing changes in this release

## Behind The Scenes

- No internal changes in this release
EOF
    exit 0
fi

echo "Commits to summarize:"
echo "$COMMITS"
echo ""

# Check if API key is available
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "ANTHROPIC_API_KEY not set, using fallback"
    cat > "$OUTPUT_FILE" << EOF
## Functionality

$(echo "$COMMITS" | grep -iE "^(add|fix|update|improve)" | sed 's/^/- /' | head -10 || echo "- See commit history for changes")

## Behind The Scenes

$(echo "$COMMITS" | grep -iE "^(test|refactor|ci|cd|migration|internal|bump)" | sed 's/^/- /' | head -10 || echo "- Various improvements")
EOF
    exit 0
fi

# Build the prompt
PROMPT="You are writing release notes for KlipPal, a macOS clipboard manager app.

Based on these commit messages, create release notes with exactly 2 sections:

## Functionality
User-facing changes: new features, UI improvements, bug fixes users would notice. Use bullet points. Be concise but descriptive. Focus on what users can now do or what's fixed.

## Behind The Scenes
Internal changes: testing, database migrations, code refactoring, performance improvements, CI/CD changes. Use bullet points. Be concise.

If a section has no relevant commits, write 'No changes in this release.'

Commit messages:
$COMMITS

Write ONLY the two sections with their headers, no introduction or conclusion."

# Escape prompt for JSON
PROMPT_JSON=$(echo "$PROMPT" | jq -Rs .)

# Call Claude API
echo "Calling Claude API..."
RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
    -H "Content-Type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "{
        \"model\": \"claude-sonnet-4-20250514\",
        \"max_tokens\": 1024,
        \"messages\": [{\"role\": \"user\", \"content\": $PROMPT_JSON}]
    }")

# Extract text content
RELEASE_NOTES=$(echo "$RESPONSE" | jq -r '.content[0].text // empty')

if [ -z "$RELEASE_NOTES" ]; then
    echo "Claude API call failed, using fallback"
    echo "Response: $RESPONSE"
    cat > "$OUTPUT_FILE" << EOF
## Functionality

$(echo "$COMMITS" | grep -iE "^(add|fix|update|improve)" | sed 's/^/- /' | head -10 || echo "- See commit history for changes")

## Behind The Scenes

$(echo "$COMMITS" | grep -iE "^(test|refactor|ci|cd|migration|internal|bump)" | sed 's/^/- /' | head -10 || echo "- Various improvements")
EOF
else
    echo "$RELEASE_NOTES" > "$OUTPUT_FILE"
fi

echo ""
echo "Generated release notes:"
cat "$OUTPUT_FILE"
