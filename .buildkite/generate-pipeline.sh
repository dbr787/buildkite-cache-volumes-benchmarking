#!/bin/bash
set -euo pipefail

echo "Generating simple single-step npm install benchmark pipeline"

# Generate simple pipeline
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
  - label: ":package: npm install benchmark"
    command: |
      # Record when this job started
      JOB_START_TIME=$(date +%H:%M:%S)
      mkdir -p cache-meta
      
      # Check cache status 
      EXISTING_FILES=$(ls cache-meta/ 2>/dev/null || true)
      if [ -z "$EXISTING_FILES" ]; then
        CACHE_STATUS="💨 Cache Miss"
      else
        CACHE_STATUS="🎯 Cache Hit"
      fi
      
      # Create package.json and measure npm install
      cat > package.json <<'JSON'
      {
        "name": "demo",
        "version": "1.0.0",
        "dependencies": {
          "next": "14.2.5",
          "react": "18.3.1",
          "react-dom": "18.3.1",
          "typescript": "5.6.2",
          "webpack": "5.93.0",
          "tailwindcss": "3.4.10"
        }
      }
JSON
      
      START_TIME=$(date +%s)
      npm install
      END_TIME=$(date +%s)
      DURATION=$((END_TIME - START_TIME))
      
      # Mark this build
      touch "cache-meta/build-$BUILDKITE_BUILD_NUMBER-step-1"
      
      # Show results
      buildkite-agent annotate --context "cache-benchmark" --style "info" "### Cache Benchmark Result
      
      | Build | Started | Duration | Cache Status |
      |-------|---------|----------|--------------|
      | \`#$BUILDKITE_BUILD_NUMBER\` | \`$JOB_START_TIME\` | \`${DURATION}s\` | $CACHE_STATUS |"
PIPELINE

# Display the generated pipeline for debugging
echo "Generated pipeline:"
cat pipeline.yml

# Upload the generated pipeline
buildkite-agent pipeline upload pipeline.yml
