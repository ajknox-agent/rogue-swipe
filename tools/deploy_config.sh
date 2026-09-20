#!/usr/bin/env bash
set -e

# Rogue Swipe — Fast Config Deployment Script
# Deploys changes to config.json directly to GitHub Pages without rebuilding the Godot game binary!

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

if [ ! -f "config.json" ]; then
    echo "ERROR: config.json not found in $REPO_DIR"
    exit 1
fi

# 1. Validate JSON syntax
echo "Validating config.json syntax..."
python3 -m json.tool config.json > /dev/null
echo "✓ JSON syntax valid."

CONFIG_VERSION=$(python3 -c "import json; print(json.load(open('config.json'))['config_version'])")
CONFIG_NAME=$(python3 -c "import json; print(json.load(open('config.json'))['config_name'])")

echo "Deploying Config: $CONFIG_NAME (v$CONFIG_VERSION)..."

# 2. Copy to web_build
mkdir -p web_build
cp config.json web_build/config.json

# 3. Commit to main if changed
if ! git diff --quiet config.json; then
    echo "Committing config.json to main..."
    git add config.json
    git commit -m "Live Config Update: $CONFIG_NAME (v$CONFIG_VERSION)"
    git push origin main
fi

# 4. Deploy config.json directly to gh-pages
echo "Deploying config.json to gh-pages branch..."
git fetch origin gh-pages

TEMP_INDEX=$(mktemp)
export GIT_INDEX_FILE="$TEMP_INDEX"
git read-tree origin/gh-pages
git add -f web_build/config.json
# Move it to root in gh-pages tree
TREE=$(git write-tree)
# If config was added under web_build/ in index, let's ensure it's at root in gh-pages:
rm -f "$TEMP_INDEX"

# Alternative clean tree update for gh-pages:
export GIT_INDEX_FILE="$TEMP_INDEX"
git --work-tree=web_build add config.json
BLOB_ID=$(git hash-object -w config.json)
# Update gh-pages commit by reading origin/gh-pages tree, replacing/adding config.json
TREE=$(python3 -c "
import subprocess
out = subprocess.check_output(['git', 'ls-tree', 'origin/gh-pages']).decode('utf-8')
entries = [line for line in out.strip().split('\n') if not line.endswith('\tconfig.json')]
entries.append('100644 blob $BLOB_ID\tconfig.json')
mktree = subprocess.Popen(['git', 'mktree'], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
new_tree, _ = mktree.communicate('\n'.join(entries).encode('utf-8'))
print(new_tree.decode('utf-8').strip())
")
rm -f "$TEMP_INDEX"

COMMIT=$(git commit-tree "$TREE" -p origin/gh-pages -m "Live Config Update: $CONFIG_NAME (v$CONFIG_VERSION)")
git push origin "$COMMIT":refs/heads/gh-pages

echo "======================================================="
echo "✓ LIVE CONFIG DEPLOYED SUCCESSFULLY!"
echo "Version: $CONFIG_NAME (v$CONFIG_VERSION)"
echo "Live URL: https://ajknox-agent.github.io/rogue-swipe/"
echo "No wasm/pck rebuild was required!"
echo "======================================================="
