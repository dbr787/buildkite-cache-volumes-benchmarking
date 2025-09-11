# Buildkite Cache Volumes Example

[![Add to Buildkite](https://buildkite.com/button.svg)](https://buildkite.com/new?template=https://github.com/dbr787/buildkite-cache-volumes-example)

A simple example demonstrating Buildkite's cache volumes by showing npm install performance with and without cached dependencies.

## Quick Test

1. Create a Buildkite pipeline pointing to this repository  
2. Trigger a build - first build shows 💨 **Cache Miss** (90+ seconds)
3. Trigger 2-3 more builds - you should see 🎯 **Cache Hit** (10-15 seconds)

**Note:** Cache hits may not appear immediately as Buildkite's distributed cache system needs time to populate across the agent fleet. Run several builds to see the full caching effect.

## How it works

The pipeline runs a single npm install step that:
- **Creates a package.json** with common React/Next.js dependencies
- **Checks for cached node_modules** before running npm install
- **Shows cache status** in a simple results table

Results appear as an annotation showing whether the build was a cache hit or miss.

## What you'll see

**First build**: 
```
| Build | Status |
|-------|--------|
| #123  | 💨 Cache Miss |
```

**Subsequent builds**:
```
| Build | Status |
|-------|--------|
| #124  | 🎯 Cache Hit |
```

## Cache behavior

- **Cache Miss**: No `node_modules` exists, npm downloads and installs 20+ packages (~90-120s)
- **Cache Hit**: `node_modules` exists from previous builds, npm skips most work (~10-15s)
- **Shared across branches**: All branches use the same cache for realistic performance
- **Distributed system**: Cache volumes may take 2-3 builds to fully populate across agent infrastructure

## Files

- `.buildkite/pipeline.yml` - The complete cache example pipeline
- `.buildkite/template.yml` - Template for "Add to Buildkite" button
