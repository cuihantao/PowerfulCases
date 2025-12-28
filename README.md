# PowerfulCases

Test case data management for power systems simulation. Works with Julia, Python, and MATLAB.

## Installation

**Julia:**
```julia
using Pkg
Pkg.add(url="https://github.com/cuihantao/PowerfulCases")
```

**Python:**
```bash
pip install powerfulcases
```

**MATLAB:**
```matlab
% Clone the repo, then run:
pcase_install
```

## Your Data, Your Way

**PowerfulCases works with your proprietary case files.** Point it at any directory containing `.raw`, `.dyr`, or other power system data files:

```julia
# Julia
using PowerfulCases

case = load("/projects/utility-data/summer-peak-2024")
case.raw   # → /projects/utility-data/summer-peak-2024/model.raw
case.dyr   # → /projects/utility-data/summer-peak-2024/dynamics.dyr
```

```python
# Python
import powerfulcases as pcase

case = pcase.load("/projects/utility-data/summer-peak-2024")
case.raw   # → /projects/utility-data/summer-peak-2024/model.raw
case.dyr   # → /projects/utility-data/summer-peak-2024/dynamics.dyr
```

```matlab
% MATLAB
case = pcase.load('/projects/utility-data/summer-peak-2024');
case.raw   % → /projects/utility-data/summer-peak-2024/model.raw
case.dyr   % → /projects/utility-data/summer-peak-2024/dynamics.dyr
```

No configuration needed for standard extensions. For advanced use cases (multiple DYR variants, format versions), add a `manifest.toml`:

```bash
# Generate a manifest template
pcase create-manifest /projects/utility-data/summer-peak-2024
```

This is the recommended workflow for researchers with proprietary utility data, custom test cases, or any data that can't be shared publicly.

## Built-in Test Cases

Standard IEEE and synthetic cases are included for testing and benchmarking:

```julia
# Julia
using PowerfulCases

case = load("ieee14")
case.raw                                    # Default RAW file
case.dyr                                    # Default DYR file
file(case, :dyr, variant="genrou")      # Specific dynamic model variant

cases()                    # All available cases
formats(case)              # Formats in this case
variants(case, :dyr)       # Available DYR variants
```

```python
# Python
import powerfulcases as pcase

case = pcase.load("ieee14")
case.raw
case.dyr
pcase.file(case, "psse_dyr", variant="genrou")

pcase.cases()
pcase.formats(case)
pcase.variants(case, "psse_dyr")
```

```matlab
% MATLAB
case = pcase.load('ieee14');
case.raw
case.dyr
pcase.file(case, 'psse_dyr', 'variant', 'genrou')

pcase.cases()
pcase.formats(case)
pcase.variants(case, 'psse_dyr')
```

### Available Cases

| Case | Description |
|------|-------------|
| `ieee14` | IEEE 14-bus test system |
| `ieee39` | IEEE 39-bus (New England) system |
| `ieee118` | IEEE 118-bus system |
| `ACTIVSg2000` | ACTIVS 2000-bus synthetic grid |
| `ACTIVSg10k` | ACTIVS 10,000-bus synthetic grid |
| `ACTIVSg70k` | ACTIVS 70,000-bus synthetic grid (large, downloaded on demand) |
| `case5`, `case9` | Small test cases |
| `npcc` | NPCC test system |

## Command-Line Interface (Python)

The `pcase` CLI helps manage cases and cache:

```bash
# List all available cases
pcase list

# Pre-download large cases before running benchmarks
pcase download ACTIVSg70k

# Check what's in your cache
pcase cache-info

# Inspect a case's contents
pcase info ieee14

# Generate manifest for your own data
pcase create-manifest /path/to/your/case
```

> **Note:** `powerfulcases` also works as a long-form alias.

### Pre-downloading for Offline Work

Large cases (>2MB) are not bundled with the package. Download them once, then work offline:

```bash
# Download before a long flight or cluster job
pcase download ACTIVSg70k
pcase download ACTIVSg10k

# Verify downloads
pcase cache-info
```

Cases are cached in `~/.powerfulcases/` and persist across sessions.

### CI/CD Integration

Pre-download cases in your CI setup:

```yaml
# GitHub Actions example
- name: Setup test data
  run: |
    pip install powerfulcases
    pcase download ACTIVSg2000
```

## Manifest Files

A `manifest.toml` describes case contents when you need more than basic file discovery:

```toml
name = "summer-peak-2024"
description = "Utility summer peak case with multiple dynamic variants"

[[files]]
path = "base.raw"
format = "psse_raw"
format_version = "34"
default = true

[[files]]
path = "dynamics_full.dyr"
format = "psse_dyr"
default = true

[[files]]
path = "dynamics_simplified.dyr"
format = "psse_dyr"
variant = "simplified"

[credits]
license = "proprietary"
authors = ["Grid Operations Team"]
```

**When you need a manifest:**
- Multiple files of the same format (e.g., several DYR variants)
- Ambiguous extensions (`.m` could be MATPOWER or PSAT)
- Format version tracking (PSS/E v33 vs v34)
- Attribution and licensing metadata

**When you don't need a manifest:**
- Single `.raw` file → auto-detected as PSS/E RAW
- Single `.dyr` file → auto-detected as PSS/E DYR
- Simple cases with obvious file types

## Cache Management

```julia
# Julia
using PowerfulCases

download("ACTIVSg70k")     # Pre-download
info()                    # Show cache status
clear("ACTIVSg70k")       # Remove specific case
clear()                   # Clear everything
set_cache_dir("/custom/path")   # Change cache location
```

```python
# Python
import powerfulcases as pcase

pcase.download("ACTIVSg70k")
pcase.info()
pcase.clear("ACTIVSg70k")
```

```matlab
% MATLAB
pcase.download('ACTIVSg70k')
pcase.info()
pcase.clear('ACTIVSg70k')
```

```bash
# Python CLI
pcase download ACTIVSg70k
pcase cache-info
pcase clear-cache ACTIVSg70k
pcase clear-cache --all
```

## Format Aliases

Short names for common formats:

| Julia | Python/MATLAB | Full Format |
|-------|---------------|-------------|
| `:raw` | `'raw'` | `psse_raw` |
| `:dyr` | `'dyr'` | `psse_dyr` |

## Legacy API

The old function-based API still works but emits deprecation warnings:

```julia
# Old (deprecated)
using PowerfulCases
case = ieee14()

# New (recommended)
case = load("ieee14")
```

## License

MIT
