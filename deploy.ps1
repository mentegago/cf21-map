# Flutter Web to GitHub Pages Deployment Script
# This script builds and deploys your Flutter web app to GitHub Pages

Write-Host "🚀 Starting deployment to GitHub Pages..." -ForegroundColor Cyan

# Check if Flutter is installed
if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Flutter not found. Please install Flutter first." -ForegroundColor Red
    exit 1
}

# Clean previous builds
Write-Host "🧹 Cleaning previous builds..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build for web (release mode)
Write-Host "🔨 Building Flutter web app..." -ForegroundColor Yellow
flutter build web --release --web-renderer canvaskit --base-href /

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Build successful!" -ForegroundColor Green

# Check if gh-pages branch exists
$branchExists = git show-ref --verify --quiet refs/heads/gh-pages
if ($LASTEXITCODE -ne 0) {
    Write-Host "📝 Creating gh-pages branch..." -ForegroundColor Yellow
    git checkout --orphan gh-pages
    git reset --hard
    git commit --allow-empty -m "Initial gh-pages commit"
    git checkout main
}

# Copy build to temporary location
Write-Host "📋 Preparing deployment files..." -ForegroundColor Yellow
$tempDir = New-Item -ItemType Directory -Path "$env:TEMP\flutter-web-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')" -Force
Copy-Item -Path "build\web\*" -Destination $tempDir -Recurse -Force

# Switch to gh-pages branch
Write-Host "🔄 Switching to gh-pages branch..." -ForegroundColor Yellow
git checkout gh-pages

# Remove old files (except .git)
Write-Host "🗑️ Removing old deployment files..." -ForegroundColor Yellow
Get-ChildItem -Path . -Exclude '.git' | Remove-Item -Recurse -Force

# Copy new build
Write-Host "📥 Copying new build..." -ForegroundColor Yellow
Copy-Item -Path "$tempDir\*" -Destination . -Recurse -Force

# Clean up temp directory
Remove-Item -Path $tempDir -Recurse -Force

# Add .nojekyll file (important for GitHub Pages)
New-Item -Path ".nojekyll" -ItemType File -Force | Out-Null

# Stage all changes
Write-Host "📦 Staging changes..." -ForegroundColor Yellow
git add .

# Commit changes
$commitMessage = "Deploy: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "💾 Committing changes..." -ForegroundColor Yellow
git commit -m $commitMessage

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ No changes to commit" -ForegroundColor Yellow
    git checkout main
    exit 0
}

# Push to GitHub
Write-Host "🚀 Pushing to GitHub..." -ForegroundColor Yellow
Write-Host "⚠️ About to push to gh-pages branch. Continue? (Y/N)" -ForegroundColor Yellow
$response = Read-Host
if ($response -eq 'Y' -or $response -eq 'y') {
    git push origin gh-pages --force
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully deployed to GitHub Pages!" -ForegroundColor Green
        Write-Host "🌐 Your site will be available at your configured domain (check web/CNAME)" -ForegroundColor Cyan
        Write-Host "⏱️ It may take a few minutes for changes to appear." -ForegroundColor Yellow
    } else {
        Write-Host "❌ Push failed!" -ForegroundColor Red
        git checkout main
        exit 1
    }
} else {
    Write-Host "❌ Deployment cancelled" -ForegroundColor Red
}

# Switch back to main branch
Write-Host "🔄 Switching back to main branch..." -ForegroundColor Yellow
git checkout main

Write-Host "✨ Done!" -ForegroundColor Green

