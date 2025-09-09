#!/bin/bash
set -euo pipefail

STEP_NUMBER=${1:-1}
CACHE_SLEEP=${2:-60}
PREVIOUS_STEP_NUMBER=$((STEP_NUMBER - 1))

mkdir -p cache-meta

# Check cache status based on existing cache-meta files  
PREVIOUS_STEP_FILE="build-$BUILDKITE_BUILD_NUMBER-step-install-$PREVIOUS_STEP_NUMBER"

EXISTING_FILES=$(ls cache-meta/ 2>/dev/null || true)
if [ -z "$EXISTING_FILES" ]; then
  CACHE_STATUS="🔴 Cold"
elif [ -f "cache-meta/$PREVIOUS_STEP_FILE" ]; then
  LAST_TOUCHED=$(stat -c %y "cache-meta/$PREVIOUS_STEP_FILE" | cut -d' ' -f2 | cut -d'.' -f1)
  CACHE_STATUS="🟢 Hot (step #$PREVIOUS_STEP_NUMBER at $LAST_TOUCHED)"
elif ls cache-meta/build-$BUILDKITE_BUILD_NUMBER-step-* 2>/dev/null >/dev/null; then
  LATEST_FILE=$(ls -t cache-meta/build-$BUILDKITE_BUILD_NUMBER-step-* 2>/dev/null | head -1)
  LATEST_STEP=$(basename "$LATEST_FILE" | sed 's/build-[0-9]*-step-install-//')
  LAST_TOUCHED=$(stat -c %y "$LATEST_FILE" | cut -d' ' -f2 | cut -d'.' -f1)
  CACHE_STATUS="🔵 Warm (step #$LATEST_STEP at $LAST_TOUCHED)"
else
  LATEST_FILE=$(ls -t cache-meta/ 2>/dev/null | head -1)
  LATEST_BUILD=$(basename "$LATEST_FILE" | sed 's/build-\([0-9]*\)-step-install-.*/\1/')
  LATEST_STEP=$(basename "$LATEST_FILE" | sed 's/build-[0-9]*-step-install-//')
  LAST_TOUCHED=$(stat -c %y "cache-meta/$LATEST_FILE" | cut -d' ' -f2 | cut -d'.' -f1)
  CACHE_STATUS="🟠 Cool (build #$LATEST_BUILD step #$LATEST_STEP at $LAST_TOUCHED)"
fi

touch "cache-meta/build-$BUILDKITE_BUILD_NUMBER-step-install-$STEP_NUMBER"
ls -lt cache-meta

cat > package.json <<'JSON'
{
  "name": "demo",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "next": "14.2.5",
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "typescript": "5.6.2",
    "eslint": "9.9.0",
    "webpack": "5.93.0",
    "tailwindcss": "3.4.10",
    "postcss": "8.4.45",
    "autoprefixer": "10.4.19",
    "prisma": "5.17.0",
    "sharp": "0.33.4",
    "puppeteer": "23.4.1"
  }
}
JSON

# Time the npm install
START_TIME=$(date +%s)
npm install
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Store results in build metadata for table reconstruction  
buildkite-agent meta-data set "benchmark-step-$STEP_NUMBER" "$STEP_NUMBER|$CACHE_SLEEP|$DURATION|$CACHE_STATUS"

# Rebuild the entire annotation table
TABLE_HEADER="### Cache Volume Benchmark Results

| Step | Sleep | Duration | Cache Status |
|------|-------|----------|--------------|"

TABLE_ROWS=""
for ((step=1; step<=STEP_NUMBER; step++)); do
  STEP_DATA=$(buildkite-agent meta-data get "benchmark-step-$step" 2>/dev/null || echo "")
  if [ -n "$STEP_DATA" ]; then
    IFS='|' read -r step_num sleep_duration duration cache_status <<< "$STEP_DATA"
    TABLE_ROWS="${TABLE_ROWS}
| npm install #$step_num | ${sleep_duration}s | ${duration}s | $cache_status |"
  fi
done

# Update the complete annotation
printf '%s%s' "$TABLE_HEADER" "$TABLE_ROWS" | buildkite-agent annotate --context "cache-benchmark" --style "info"
