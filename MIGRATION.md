# Migration Guide: Coverage.jl Modernization

This guide helps you migrate from the deprecated direct upload functionality to the new official uploader integration.

## What Changed?

Coverage.jl has been modernized to work with the official uploaders from Codecov and Coveralls, as both services have deprecated support for 3rd party uploaders.

### Before (Deprecated ❌)
```julia
using Coverage
fcs = process_folder("src")
Codecov.submit(fcs)           # ❌ Deprecated
Coveralls.submit(fcs)         # ❌ Deprecated
```

### After (Modern ✅)
```julia
using Coverage
fcs = process_folder("src")

# Option 1: Use automated upload (recommended)
using Coverage.CIIntegration
process_and_upload(service=:both, folder="src")

# Option 2: Prepare data for manual upload
using Coverage.CodecovExport, Coverage.CoverallsExport
codecov_file = prepare_for_codecov(fcs, format=:lcov)
coveralls_file = prepare_for_coveralls(fcs, format=:lcov)
```

## Migration Steps

### 1. For CI Environments (GitHub Actions, Travis, etc.)

**Option A: Use the automated helper (easiest)**
```julia
using Coverage, Coverage.CIIntegration
process_and_upload(service=:both, folder="src")
```

**Option B: Use official uploaders directly**
```yaml
# GitHub Actions example
- name: Process coverage to LCOV
  run: |
    julia -e '
      using Pkg; Pkg.add("Coverage")
      using Coverage, Coverage.LCOV
      coverage = process_folder("src")
      LCOV.writefile("coverage.info", coverage)
    '

- name: Upload to Codecov
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage.info
    token: ${{ secrets.CODECOV_TOKEN }}

- name: Upload to Coveralls
  uses: coverallsapp/github-action@v2
  with:
    files: ./coverage.info
```

### 2. For Local Development

```julia
using Coverage, Coverage.CIIntegration

# Process and upload
fcs = process_folder("src")
upload_to_codecov(fcs; token="your_token", dry_run=true)  # Test first
upload_to_codecov(fcs; token="your_token")               # Actual upload
```

### 3. Using Helper Scripts

```bash
# Upload to both services
julia scripts/upload_coverage.jl --folder src

# Upload only to Codecov
julia scripts/upload_coverage.jl --service codecov --flags julia

# Dry run to test
julia scripts/upload_coverage.jl --dry-run
```

## New Modules

### Coverage.CodecovExport
- `prepare_for_codecov()` - Export coverage in Codecov-compatible formats
- `download_codecov_uploader()` - Download official Codecov uploader
- `export_codecov_json()` - Export to JSON format

### Coverage.CoverallsExport
- `prepare_for_coveralls()` - Export coverage in Coveralls-compatible formats
- `download_coveralls_reporter()` - Download Universal Coverage Reporter
- `export_coveralls_json()` - Export to JSON format

### Coverage.CIIntegration
- `process_and_upload()` - One-stop function for processing and uploading
- `upload_to_codecov()` - Upload to Codecov using official uploader
- `upload_to_coveralls()` - Upload to Coveralls using official reporter
- `detect_ci_platform()` - Detect current CI environment

## Environment Variables

| Variable | Service | Description |
|----------|---------|-------------|
| `CODECOV_TOKEN` | Codecov | Repository token for Codecov |
| `COVERALLS_REPO_TOKEN` | Coveralls | Repository token for Coveralls |
| `CODECOV_FLAGS` | Codecov | Comma-separated flags |
| `CODECOV_NAME` | Codecov | Upload name |

## Supported Formats

- **LCOV** (`.info`) - Recommended, supported by both services
- **JSON** - Native format for each service
- **XML** - Codecov only (via LCOV conversion)

## Platform Support

The modernized Coverage.jl automatically downloads the appropriate uploader for your platform:
- **Linux** (x64, ARM64)
- **macOS** (x64, ARM64)
- **Windows** (x64)

## Troubleshooting

### Deprecation Warnings
If you see deprecation warnings, update your code:
```julia
# Old
Codecov.submit(fcs)

# New
using Coverage.CIIntegration
upload_to_codecov(fcs)
```

### Missing Tokens
Set environment variables or pass tokens explicitly:
```bash
export CODECOV_TOKEN="your_token"
export COVERALLS_REPO_TOKEN="your_token"
```

### CI Platform Not Detected
The modern uploaders handle CI detection automatically. If needed, you can force CI parameters:
```julia
upload_to_codecov(fcs; token="manual_token")
```

For more examples, see the `examples/ci/` directory.
