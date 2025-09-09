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
      buildkite-agent annotate --context "cache-benchmark" --style "info" $'### Cache Volume Benchmark Results\n\n| Step | Sleep | Duration | Cache Status |\n|------|-------|----------|--------------|'
  - wait
PIPELINE

# Generate npm install steps with sleeps between them
for i in $(seq 1 ${REPEAT}); do
  LABEL=":package: npm install #${i}"
  
  # Add npm install step
  cat >> pipeline.yml <<STEP
  - label: "${LABEL}"
    key: install-${i}
    command: "./.buildkite/benchmark-step.sh ${i} ${CACHE_SLEEP} ${REPEAT}"
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
