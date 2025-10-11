#!/bin/bash
# Flutter Web to GitHub Pages Deployment Script
# This script builds and deploys your Flutter web app to GitHub Pages

set -e

echo "🚀 Starting deployment to GitHub Pages..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web (release mode)
echo "🔨 Building Flutter web app..."
flutter build web --release --web-renderer canvaskit --base-href /

echo "✅ Build successful!"

# Check if gh-pages branch exists
if ! git show-ref --verify --quiet refs/heads/gh-pages; then
    echo "📝 Creating gh-pages branch..."
    git checkout --orphan gh-pages
    git reset --hard
    git commit --allow-empty -m "Initial gh-pages commit"
    git checkout main
fi

# Copy build to temporary location
echo "📋 Preparing deployment files..."
TEMP_DIR=$(mktemp -d)
cp -r build/web/* "$TEMP_DIR/"

# Switch to gh-pages branch
echo "🔄 Switching to gh-pages branch..."
git checkout gh-pages

# Remove old files (except .git)
echo "🗑️ Removing old deployment files..."
find . -maxdepth 1 ! -name '.git' ! -name '.' ! -name '..' -exec rm -rf {} +

# Copy new build
echo "📥 Copying new build..."
cp -r "$TEMP_DIR"/* .

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Add .nojekyll file (important for GitHub Pages)
touch .nojekyll

# Stage all changes
echo "📦 Staging changes..."
git add .

# Commit changes
COMMIT_MESSAGE="Deploy: $(date '+%Y-%m-%d %H:%M:%S')"
echo "💾 Committing changes..."
if git commit -m "$COMMIT_MESSAGE"; then
    # Push to GitHub
    echo "🚀 Pushing to GitHub..."
    echo "⚠️ About to push to gh-pages branch. Continue? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        git push origin gh-pages --force
        
        echo "✅ Successfully deployed to GitHub Pages!"
        echo "🌐 Your site will be available at your configured domain (check web/CNAME)"
        echo "⏱️ It may take a few minutes for changes to appear."
    else
        echo "❌ Deployment cancelled"
        git checkout main
        exit 1
    fi
else
    echo "⚠️ No changes to commit"
fi

# Switch back to main branch
echo "🔄 Switching back to main branch..."
git checkout main

echo "✨ Done!"

