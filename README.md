# Buildkite Cache Volumes Benchmarking

This repository benchmarks Buildkite's cache volumes functionality by simulating cache hits and misses through repeated npm install commands with configurable delays. It helps visualize and measure the performance difference between cold (cache miss) and warm (cache hit) scenarios.

## Usage

1. Push this repository to your Git provider
2. Create a Buildkite pipeline pointing to this repository
3. Run a build - you'll be prompted for:
   - **Number of repetitions**: How many times to run npm install
   - **Cache sleep**: Seconds to wait between each install

## How it works

1. The main pipeline (`.buildkite/pipeline.yml`) collects user input
2. The generator script (`scripts/generate-pipeline.sh`) creates a dynamic pipeline based on the input
3. The generated pipeline:
   - Creates cache marker files for each run
   - Runs npm install N times
   - Adds configurable sleep delays between runs
   - Uses Buildkite's cache volumes for `node_modules`, `.npm`, and `cache-meta`

## What This Benchmarks

- **Cold cache performance**: First npm install with no cached dependencies
- **Warm cache performance**: Subsequent npm installs with cached dependencies  
- **Cache volume persistence**: How cache volumes maintain state across steps
- **Cache hit rates**: Visual confirmation of when cache is being utilized

## Example

If you input:
- Repetitions: 3
- Cache sleep: 30

The script generates:
1. npm install #1 (cold) → wait → sleep 30s → wait
2. npm install #2 (warm) → wait → sleep 30s → wait  
3. npm install #3 (warm) → wait

## Files

- `.buildkite/pipeline.yml` - Main pipeline definition
- `scripts/generate-pipeline.sh` - Dynamic pipeline generator
- Generated `cache-meta/` files track each build and step
