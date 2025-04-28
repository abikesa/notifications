#!/bin/bash

set -e

# 🌊 0. Parse silent mode
silent=false
if [ "$1" == "--silent" ]; then
    silent=true
fi

# 🛟 1. Git info
current_branch=$(git branch --show-current)
git_remote="origin"
git_branch="$current_branch"
ghp_remote="origin"

if ! $silent; then
    read -p "📜 Commit message: " commit_message
    read -p "🛰️ Git remote to push to (default: origin): " input_git_remote
    read -p "🌿 Git branch to push to (default: $current_branch): " input_git_branch
    read -p "🚀 Remote for ghp-import (default: origin): " input_ghp_remote

    git_remote=${input_git_remote:-$git_remote}
    git_branch=${input_git_branch:-$git_branch}
    ghp_remote=${input_ghp_remote:-$ghp_remote}
else
    commit_message="Auto-deploy from $current_branch at $(date)"
fi

# 🚨 Warn if pushing to main
if [ "$git_branch" = "main" ] && ! $silent; then
    echo "⚠️  WARNING: You are about to push to 'main'."
    read -p "Type 'confirm' to proceed: " confirm
    if [ "$confirm" != "confirm" ]; then
        echo "🛑 Push to main aborted."
        exit 1
    fi
fi

# 🛠️ 2. Clean and rebuild
echo "🧼 Cleaning old builds..."
jb clean . || echo "⚠️ Clean skipped (already clean?)"

[ -f bash/bash_clean.sh ] && bash bash/bash_clean.sh || echo "ℹ️ No extended clean script."

echo "🏗️ Building Jupyter Book..."
jb build . || { echo "❌ Build failed."; exit 1; }

# 🍱 3. Copy extra folders
dirs=( pdfs figures media testbin nis myhtml dedication python ai r stata bash xml data aperitivo antipasto primo secondo contorno insalata formaggio-e-frutta dolce caffe digestivo ukubona )
shopt -s dotglob nullglob
for d in "${dirs[@]}"; do
    [ -d "$d" ] && mkdir -p "_build/html/$d" && cp -r "$d"/* "_build/html/$d/" 2>/dev/null
done
shopt -u dotglob nullglob

# 🔎 4. Check if _build/html changed compared to gh-pages
echo "🔍 Checking build differences..."

temp_dir=$(mktemp -d)
git fetch "$ghp_remote" gh-pages || echo "No existing gh-pages branch found."
git worktree add "$temp_dir" gh-pages || true

pushd "$temp_dir" > /dev/null
if diff -qr --exclude='.git' "$OLDPWD/_build/html" . > /dev/null; then
    echo "🧘 No changes detected in _build/html. Skipping deployment."
else
    echo "🚀 Changes detected. Publishing to gh-pages..."
    popd > /dev/null
    ghp-import -n -p -f -r "$ghp_remote" _build/html || { echo "❌ ghp-import failed."; exit 1; }
fi
git worktree remove "$temp_dir" --force || true
rm -rf "$temp_dir"

# 🧭 5. Return to project root
cd "$(git rev-parse --show-toplevel)" || { echo "❌ Git root not found."; exit 1; }

# 🌱 6. Plant flicks
echo "🌿 Planting flicks..."
python kitabo/ensi/python/plant_flicks_frac.py --percent 23 || echo "⚠️ Flick planting issue."

# 🧾 7. Commit + push
echo "🧾 Staging changes..."
git add .

echo "✍️ Committing..."
git commit -m "$commit_message" || echo "⚠️ Nothing to commit."

echo "⬆️ Pushing to $git_remote/$git_branch..."
git push "$git_remote" "$git_branch" || echo "⚠️ Push failed."

# 🔔 8. Notify success
if command -v osascript &> /dev/null; then
    osascript -e 'display notification "Deploy complete!" with title "Ukubona Deploy 🚀"'
fi

echo "✅ Deployment complete."
