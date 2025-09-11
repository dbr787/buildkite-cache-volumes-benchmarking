#!/bin/bash
set -euo pipefail

STEP_NUMBER=${1:-1}
CACHE_SLEEP=${2:-60}
TOTAL_STEPS=${3:-5}
PREVIOUS_STEP_NUMBER=$((STEP_NUMBER - 1))

# Record when this job started
JOB_START_TIME=$(date +%H:%M:%S)

# Cache strategy: branch-specific with main fallback
BRANCH_PREFIX=${BUILDKITE_BRANCH%%/*}
MAIN_CACHE_DIR="/cache/main"
BRANCH_CACHE_DIR="/cache/${BRANCH_PREFIX}"

# Ensure cache directories exist
mkdir -p "$MAIN_CACHE_DIR" "$BRANCH_CACHE_DIR" cache-meta

# Cache selection logic
if [ "$BUILDKITE_BRANCH" = "main" ]; then
    # Main branch: use main cache only
    ACTIVE_CACHE_DIR="$MAIN_CACHE_DIR"
    CACHE_SOURCE="main"
    echo "🏠 Using main cache: $ACTIVE_CACHE_DIR"
else
    # Feature branch: try branch cache first, fallback to main
    if [ -d "$BRANCH_CACHE_DIR/node_modules" ] && [ "$(ls -A $BRANCH_CACHE_DIR/node_modules 2>/dev/null)" ]; then
        # Branch cache exists and has content
        ACTIVE_CACHE_DIR="$BRANCH_CACHE_DIR"
        CACHE_SOURCE="branch"
        echo "🌿 Using branch cache: $ACTIVE_CACHE_DIR"
    elif [ -d "$MAIN_CACHE_DIR/node_modules" ] && [ "$(ls -A $MAIN_CACHE_DIR/node_modules 2>/dev/null)" ]; then
        # No branch cache, but main cache exists - copy it over
        echo "📋 Copying main cache to branch cache..."
        cp -r "$MAIN_CACHE_DIR"/* "$BRANCH_CACHE_DIR"/ 2>/dev/null || true
        ACTIVE_CACHE_DIR="$BRANCH_CACHE_DIR"
        CACHE_SOURCE="inherited-from-main"
        echo "🔄 Using inherited cache: $ACTIVE_CACHE_DIR"
    else
        # No cache exists anywhere
        ACTIVE_CACHE_DIR="$BRANCH_CACHE_DIR"
        CACHE_SOURCE="cold"
        echo "❄️ Cold start - creating new branch cache: $ACTIVE_CACHE_DIR"
    fi
fi

# Create symbolic links to the active cache
rm -rf node_modules .npm 2>/dev/null || true
ln -sf "$ACTIVE_CACHE_DIR/node_modules" ./node_modules 2>/dev/null || true
ln -sf "$ACTIVE_CACHE_DIR/.npm" ./.npm 2>/dev/null || true

# Check cache status based on cache-meta in the active cache directory
PREVIOUS_STEP_FILE="$ACTIVE_CACHE_DIR/cache-meta/build-$BUILDKITE_BUILD_NUMBER-step-install-$PREVIOUS_STEP_NUMBER"

EXISTING_FILES=$(ls "$ACTIVE_CACHE_DIR/cache-meta/" 2>/dev/null || true)
CURRENT_TIME=$(date +%s)

if [ -z "$EXISTING_FILES" ]; then
    CACHE_STATUS="❄️ \`Cold ($CACHE_SOURCE)\`"
elif [ -f "$PREVIOUS_STEP_FILE" ]; then
    LAST_TOUCHED_TIME=$(stat -c %Y "$PREVIOUS_STEP_FILE")
    LAST_TOUCHED=$(stat -c %y "$PREVIOUS_STEP_FILE" | cut -d' ' -f2 | cut -d'.' -f1)
    AGE_SECONDS=$((CURRENT_TIME - LAST_TOUCHED_TIME))
    CACHE_STATUS="🔥 \`Hot ($CACHE_SOURCE)\` \`build: $BUILDKITE_BUILD_NUMBER\` \`step: npm install #$PREVIOUS_STEP_NUMBER\` \`touched: $LAST_TOUCHED\` \`age: ${AGE_SECONDS}s\`"
elif ls "$ACTIVE_CACHE_DIR/cache-meta/build-$BUILDKITE_BUILD_NUMBER-step-"* 2>/dev/null >/dev/null; then
    LATEST_FILE=$(ls -t "$ACTIVE_CACHE_DIR/cache-meta/build-$BUILDKITE_BUILD_NUMBER-step-"* 2>/dev/null | head -1)
    LATEST_STEP=$(basename "$LATEST_FILE" | sed 's/build-[0-9]*-step-install-//')
    LAST_TOUCHED_TIME=$(stat -c %Y "$LATEST_FILE")
    LAST_TOUCHED=$(stat -c %y "$LATEST_FILE" | cut -d' ' -f2 | cut -d'.' -f1)
    AGE_SECONDS=$((CURRENT_TIME - LAST_TOUCHED_TIME))
    CACHE_STATUS="☀️ \`Warm ($CACHE_SOURCE)\` \`build: $BUILDKITE_BUILD_NUMBER\` \`step: npm install #$LATEST_STEP\` \`touched: $LAST_TOUCHED\` \`age: ${AGE_SECONDS}s\`"
else
    LATEST_FILE=$(ls -t "$ACTIVE_CACHE_DIR/cache-meta/" 2>/dev/null | head -1)
    if [ -n "$LATEST_FILE" ]; then
        LATEST_BUILD=$(basename "$LATEST_FILE" | sed 's/build-\([0-9]*\)-step-install-.*/\1/')
        LATEST_STEP=$(basename "$LATEST_FILE" | sed 's/build-[0-9]*-step-install-//')
        LAST_TOUCHED_TIME=$(stat -c %Y "$ACTIVE_CACHE_DIR/cache-meta/$LATEST_FILE")
        LAST_TOUCHED=$(stat -c %y "$ACTIVE_CACHE_DIR/cache-meta/$LATEST_FILE" | cut -d' ' -f2 | cut -d'.' -f1)
        AGE_SECONDS=$((CURRENT_TIME - LAST_TOUCHED_TIME))
        
        # Check if this is step 1 of current build AND cache is from last step of immediate previous build (Hot scenario)
        IMMEDIATE_PREVIOUS_BUILD=$((BUILDKITE_BUILD_NUMBER - 1))
        if [ "$STEP_NUMBER" -eq 1 ] && [ "$LATEST_BUILD" -eq "$IMMEDIATE_PREVIOUS_BUILD" ] && [ "$LATEST_STEP" -eq "$TOTAL_STEPS" ]; then
            CACHE_STATUS="🔥 \`Hot ($CACHE_SOURCE)\` \`build: $LATEST_BUILD\` \`step: npm install #$LATEST_STEP (last step)\` \`touched: $LAST_TOUCHED\` \`age: ${AGE_SECONDS}s\`"
        else
            CACHE_STATUS="🧊 \`Cool ($CACHE_SOURCE)\` \`build: $LATEST_BUILD\` \`step: npm install #$LATEST_STEP\` \`touched: $LAST_TOUCHED\` \`age: ${AGE_SECONDS}s\`"
        fi
    else
        CACHE_STATUS="❄️ \`Cold ($CACHE_SOURCE)\`"
    fi
fi

# Create the marker file in the active cache's meta directory
mkdir -p "$ACTIVE_CACHE_DIR/cache-meta"
touch "$ACTIVE_CACHE_DIR/cache-meta/build-$BUILDKITE_BUILD_NUMBER-step-install-$STEP_NUMBER"
ls -lt "$ACTIVE_CACHE_DIR/cache-meta"

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

# Ensure node_modules is saved to the active cache directory
if [ ! -L "./node_modules" ]; then
    # If somehow the symlink was broken, move the real directory to cache
    rm -rf "$ACTIVE_CACHE_DIR/node_modules"
    mv ./node_modules "$ACTIVE_CACHE_DIR/"
    ln -sf "$ACTIVE_CACHE_DIR/node_modules" ./node_modules
fi

# Store results in build metadata for table reconstruction
if [ "$STEP_NUMBER" -eq 1 ]; then
    SLEEP_DISPLAY="\`N/A\`"
else
    SLEEP_DISPLAY="\`${CACHE_SLEEP}s\`"
fi
DURATION_DISPLAY="\`${DURATION}s\`"
buildkite-agent meta-data set "benchmark-step-$STEP_NUMBER" "$STEP_NUMBER|\`$JOB_START_TIME\`|$SLEEP_DISPLAY|$DURATION_DISPLAY|$CACHE_STATUS"

# Rebuild the entire annotation table
TABLE_HEADER="### Cache Volume Benchmark Results (Branch: \`$BUILDKITE_BRANCH\`)

| Step | Started | Sleep | Duration | Cache Status |
|------|---------|-------|----------|--------------|"

TABLE_ROWS=""
for ((step=1; step<=STEP_NUMBER; step++)); do
    STEP_DATA=$(buildkite-agent meta-data get "benchmark-step-$step" 2>/dev/null || echo "")
    if [ -n "$STEP_DATA" ]; then
        IFS='|' read -r step_num started_time sleep_display duration_display cache_status <<< "$STEP_DATA"
        TABLE_ROWS="${TABLE_ROWS}
| \`npm install #$step_num\` | $started_time | $sleep_display | $duration_display | $cache_status |"
    fi
done

# Update the complete annotation
printf '%s%s' "$TABLE_HEADER" "$TABLE_ROWS" | buildkite-agent annotate --context "cache-benchmark" --style "info"
