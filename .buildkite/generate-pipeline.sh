#!/bin/bash
set -euo pipefail

# Get metadata from input step
REPEAT=$(buildkite-agent meta-data get "repeat")
CACHE_SLEEP=$(buildkite-agent meta-data get "cache_sleep")

echo "Generating pipeline with ${REPEAT} npm install steps and ${CACHE_SLEEP} second sleeps"

# Start building the pipeline
cat > pipeline.yml <<'PIPELINE'
cache:
  name: "buildkite-cache-volumes-benchmarking"
  paths:
    - node_modules
    - .npm
    - cache-meta
env:
  NPM_CONFIG_CACHE: ".npm"
steps:
  - label: ":clipboard: Initialize benchmark results"
    command: |
      buildkite-agent annotate --context "cache-benchmark" --style "info" $'## Cache Volume Benchmark Results\n\n| Step | Duration | Cache Status |\n|------|----------|--------------|'
  - wait
PIPELINE

# Generate npm install steps with sleeps between them
for i in $(seq 1 ${REPEAT}); do
  LABEL=":package: npm install #${i}"
  
  # Add npm install step
  cat >> pipeline.yml <<STEP
  - label: "${LABEL}"
    key: install-${i}
    command: |
      mkdir -p cache-meta
      
      # Check cache status based on existing cache-meta files
      CURRENT_BUILD="\${BUILDKITE_BUILD_NUMBER}"
      PREVIOUS_STEP_FILE="build-\${CURRENT_BUILD}-step-install-$((${i}-1))"
      
      EXISTING_FILES=\$(ls cache-meta/ 2>/dev/null || true)
      if [ -z "\${EXISTING_FILES}" ]; then
        CACHE_STATUS="🔴 Cold (no cache)"
      elif [ -f "cache-meta/\${PREVIOUS_STEP_FILE}" ]; then
        LAST_TOUCHED=\$(stat -c %y "cache-meta/\${PREVIOUS_STEP_FILE}" | cut -d' ' -f2 | cut -d'.' -f1)
        CACHE_STATUS="🟢 Hot (\${PREVIOUS_STEP_FILE} at \${LAST_TOUCHED})"
      elif ls cache-meta/build-\${CURRENT_BUILD}-step-* 2>/dev/null >/dev/null; then
        LATEST_FILE=\$(ls -t cache-meta/build-\${CURRENT_BUILD}-step-* 2>/dev/null | head -1)
        LATEST_NAME=\$(basename "\${LATEST_FILE}")
        LAST_TOUCHED=\$(stat -c %y "\${LATEST_FILE}" | cut -d' ' -f2 | cut -d'.' -f1)
        SAME_BUILD_FILES=\$(ls cache-meta/build-\${CURRENT_BUILD}-step-* 2>/dev/null | wc -l)
        CACHE_STATUS="🔵 Warm (\${LATEST_NAME} at \${LAST_TOUCHED}, \${SAME_BUILD_FILES} steps)"
      else
        LATEST_FILE=\$(ls -t cache-meta/ 2>/dev/null | head -1)
        LAST_TOUCHED=\$(stat -c %y "cache-meta/\${LATEST_FILE}" | cut -d' ' -f2 | cut -d'.' -f1)
        PREV_BUILD_FILES=\$(ls cache-meta/ 2>/dev/null | wc -l)
        CACHE_STATUS="🟠 Cool (\${LATEST_FILE} at \${LAST_TOUCHED}, \${PREV_BUILD_FILES} files)"
      fi
      
      touch "cache-meta/build-\${BUILDKITE_BUILD_NUMBER}-step-install-${i}"
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
      START_TIME=\$(date +%s)
      npm install
      END_TIME=\$(date +%s)
      DURATION=\$((END_TIME - START_TIME))
      
      # Update cache status to include current job duration
      CACHE_STATUS_WITH_DURATION="\${CACHE_STATUS} (\${DURATION}s)"
      
      # Update annotation with results
      buildkite-agent annotate --context "cache-benchmark" --style "info" $'\n| npm install #${i} | '\${DURATION}$'s | '\${CACHE_STATUS_WITH_DURATION}$' |' --append
STEP
  
  # Add wait after each install
  echo "  - wait" >> pipeline.yml
  
  # Add sleep between installs (but not after the last one)
  if [ ${i} -lt ${REPEAT} ]; then
    cat >> pipeline.yml <<SLEEP
  - label: ":hourglass: cache sleep #${i}"
    key: sleep-${i}
    command: |
      echo "Sleeping for ${CACHE_SLEEP} seconds..."
      sleep ${CACHE_SLEEP}
  - wait
SLEEP
  fi
done

# Display the generated pipeline for debugging
echo "Generated pipeline:"
cat pipeline.yml

# Upload the generated pipeline
buildkite-agent pipeline upload pipeline.yml
