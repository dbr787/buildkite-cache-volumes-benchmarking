# Buildkite Cache Volumes Example

[![Add to Buildkite](https://buildkite.com/button.svg)](https://buildkite.com/new?template=https://github.com/dbr787/buildkite-cache-volumes-example)

A simple example demonstrating Buildkite's cache volumes by showing npm install performance with and without cached dependencies.

## Quick Test

1. Create a Buildkite pipeline pointing to this repository  
2. Trigger a build - first build shows 💨 **Cache Miss** (60+ seconds)
3. Trigger another build - subsequent builds show 🎯 **Cache Hit** (5-10 seconds)

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

- **Cache Miss**: No `node_modules` exists, npm downloads and installs everything (~60s)
- **Cache Hit**: `node_modules` exists from previous builds, npm skips most work (~5-10s)
- **Shared across branches**: All branches use the same cache for realistic performance

## Files

- `.buildkite/pipeline.yml` - The complete cache example pipeline
- `.buildkite/template.yml` - Template for "Add to Buildkite" button
