#!/bin/sh
# Copy shared/fixtures into the app bundle (used by demo mode). Run after regenerating them.
set -e
cd "$(dirname "$0")/.."
mkdir -p assets/fixtures
cp ../shared/fixtures/*.json assets/fixtures/
echo "synced $(ls assets/fixtures | wc -l | tr -d ' ') fixtures"
