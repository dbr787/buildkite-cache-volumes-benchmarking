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
      touch "cache-meta/build-\${BUILDKITE_BUILD_NUMBER}-step-\${BUILDKITE_STEP_KEY}"
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
      npm install
STEP
  
  # Add sleep between installs (but not after the last one)
  if [ ${i} -lt ${REPEAT} ]; then
    cat >> pipeline.yml <<SLEEP
  - wait
  - label: ":hourglass: cache sleep #${i}"
    key: sleep-${i}
    command: |
      echo "Sleeping for ${CACHE_SLEEP} seconds..."
      sleep ${CACHE_SLEEP}
SLEEP
  fi
done

# Display the generated pipeline for debugging
echo "Generated pipeline:"
cat pipeline.yml

# Upload the generated pipeline
buildkite-agent pipeline upload pipeline.yml
