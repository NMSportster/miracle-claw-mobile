#!/bin/bash
# Appends Miracle-Claw-Mobile-specific ignores to the default Flutter .gitignore.
# Run from the project root: ./scripts/append-gitignore.sh
set -e

GITIGNORE=.gitignore
cat >> "$GITIGNORE" <<'EOF'

# ---- Miracle Claw Mobile additions ----

# Flutter build artifacts (overlap with default; explicit for clarity)
/build
/.dart_tool/build

# Local config
.env
.env.local
android/key.properties
android/app/google-services.json

# IDE
.vscode/
.fleet/
.cursor/

# Crash logs
*.log
crashlytics-build/

# Screenshots / videos from device
screenshots/
*.mp4
EOF

echo "Updated $GITIGNORE"
