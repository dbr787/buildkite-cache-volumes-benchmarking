# Buildkite Cache Volumes Benchmarking

[![Add to Buildkite](https://buildkite.com/button.svg)](https://buildkite.com/new?template=https://github.com/dbr787/buildkite-cache-volumes-benchmarking)

A simple tool to benchmark Buildkite's cache volumes by measuring npm install performance with and without cached dependencies.

## Quick Test

1. Create a Buildkite pipeline pointing to this repository  
2. Trigger a build - first build shows ❄️ **Cold** cache (60+ seconds)
3. Trigger another build - subsequent builds show ☀️ **Warm** cache (5-10 seconds)

## How it works

The pipeline runs a single npm install step and measures:
- **Duration**: How long npm install takes
- **Cache status**: Cold (no cache) vs Warm (cache hit) 
- **Build tracking**: Shows which build last used the cache

Results appear in a clean annotation table showing the performance difference.

## What you'll see

**First build**: 
```
❄️ Cold | 62s | No previous cache
```

**Subsequent builds**:
```
☀️ Warm | 8s | Cache from: build-123-step-1  
```

## Cache sharing

All branches share the same cache volume - this demonstrates real-world usage where feature branches benefit from main branch's cached dependencies.

## Files

- `.buildkite/pipeline.yml` - Main pipeline entry point
- `.buildkite/generate-pipeline.sh` - Generates the benchmark pipeline  
- `.buildkite/template.yml` - Multi-step version for advanced testing
