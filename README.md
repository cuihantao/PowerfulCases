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

## Tool Integration

PowerfulCases provides test data for your existing power system analysis workflow. Here are examples for popular tools.

### Python: ANDES (Time Domain Simulation)

[ANDES](https://docs.andes.app/) is a Python library for power system modeling and simulation.

```python
import andes
import powerfulcases as pcase

# Load IEEE 14-bus with GENROU dynamic models
case = pcase.load("ieee14")

# ANDES can read PSS/E RAW + DYR directly
ss = andes.load(case.raw, addfile=pcase.file(case, "psse_dyr", variant="genrou"))

# Run power flow, then time domain simulation
ss.PFlow.run()
ss.TDS.config.tf = 10  # 10-second simulation
ss.TDS.run()

# Plot generator speeds
ss.TDS.plt.plot(ss.GENROU.omega)
```

For cases with ANDES-native Excel format:

```python
case = pcase.load("ieee14")
ss = andes.load(pcase.file(case, "andes"))  # ieee14.xlsx
```

### Python: pandapower (Power Flow & OPF)

[pandapower](https://www.pandapower.org/) can import MATPOWER cases directly.

```python
import pandapower as pp
import pandapower.converter as pc
import powerfulcases as pcase

# Load any MATPOWER case
case = pcase.load("case118zh")
net = pc.from_mpc(pcase.file(case, "matpower"))

# Run power flow
pp.runpp(net)
print(net.res_bus.head())

# Run optimal power flow
pp.runopp(net)
print(f"Total generation cost: {net.res_cost}")
```

Large-scale cases for benchmarking:

```python
# European transmission grid (13,659 buses)
pcase.download("case13659pegase")  # One-time download
case = pcase.load("case13659pegase")
net = pc.from_mpc(pcase.file(case, "matpower"))
pp.runpp(net)
```

### Python: PYPOWER (MATPOWER Port)

[PYPOWER](https://github.com/rwl/PYPOWER) is a Python port of MATPOWER.

```python
from pypower.api import runpf, runopf
from pypower.loadcase import loadcase
import powerfulcases as pcase

# Load case from file
case = pcase.load("case30Q")
ppc = loadcase(pcase.file(case, "matpower"))

# Run power flow
results, success = runpf(ppc)
print(f"Power flow {'converged' if success else 'failed'}")

# Run OPF
results, success = runopf(ppc)
```

### Python: GridCal (GUI + Scripting)

[GridCal](https://www.gridcal.org/) supports multiple import formats.

```python
import GridCal.Engine as gce
import powerfulcases as pcase

# Load from PSS/E RAW
case = pcase.load("ieee39")
grid = gce.FileOpen(case.raw).open()

# Or from MATPOWER
case = pcase.load("case2383wp")  # Polish winter peak
grid = gce.FileOpen(pcase.file(case, "matpower")).open()

# Run power flow
pf = gce.PowerFlowDriver(grid, gce.PowerFlowOptions())
pf.run()
print(grid.get_bus_df())
```

### Python: PyPSA (Network Optimization)

[PyPSA](https://pypsa.org/) focuses on energy system optimization. Use pandapower as a bridge:

```python
import pypsa
import pandapower as pp
import pandapower.converter as pc
import powerfulcases as pcase

# Load via pandapower, convert to PyPSA
case = pcase.load("case118zh")
net = pc.from_mpc(pcase.file(case, "matpower"))
network = pypsa.Network()
network.import_from_pandapower_net(net)

# Now use PyPSA for optimization
network.lopf()
```

### MATLAB: MATPOWER

[MATPOWER](https://matpower.org/) is the original tool for many bundled cases.

```matlab
% Add PowerfulCases to path
addpath('/path/to/PowerfulCases/matlab')

% Load case and run power flow
c = pcase.load('case2736sp');
mpc = loadcase(pcase.file(c, 'matpower'));
results = runpf(mpc);

% Run optimal power flow
results = runopf(mpc);
fprintf('Total cost: %.2f $/hr\n', results.f);
```

### Julia: PowerModels.jl

[PowerModels.jl](https://lanl-ansi.github.io/PowerModels.jl/) for optimization:

```julia
using PowerModels
using PowerfulCases

case = load("case118zh")
result = run_ac_opf(file(case, :matpower), ACPPowerModel, optimizer)
```

### Common Workflow Patterns

**Batch processing multiple cases:**

```python
import powerfulcases as pcase

# Test your algorithm across standard IEEE cases
for name in ["ieee14", "ieee39", "ieee118"]:
    case = pcase.load(name)
    # ... run analysis
    print(f"{name}: completed")
```

**Benchmarking with increasing scale:**

```python
import powerfulcases as pcase
import time

cases = [
    "case118zh",      # 118 buses
    "case1354pegase", # 1,354 buses
    "case2869pegase", # 2,869 buses
    "case9241pegase", # 9,241 buses (download first)
]

for name in cases:
    case = pcase.load(name)
    start = time.time()
    # ... run power flow
    print(f"{name}: {time.time() - start:.2f}s")
```

**Using your own data alongside built-in cases:**

```python
import powerfulcases as pcase

# Built-in case for validation
ieee14 = pcase.load("ieee14")

# Your proprietary data with same API
utility = pcase.load("/projects/utility-data/summer-peak")

# Same workflow for both
for case in [ieee14, utility]:
    # ... run analysis
```

## Working with Local Copies

Power system engineers often need to modify case files locally. Use `export` to copy a case to your working directory:

### Exporting Cases

**Julia:**
```julia
using PowerfulCases

# Export to current directory
export("ieee14", ".")                    # → ./ieee14/

# Export to project directory
export("ieee14", "./my-project/cases")   # → ./my-project/cases/ieee14/

# Overwrite existing
export("ieee14", ".", overwrite=true)
```

**Python:**
```python
import powerfulcases as pcase

# Export to current directory
pcase.export_case("ieee14", ".")              # → ./ieee14/

# Export to project directory
pcase.export_case("ieee14", "./my-project/cases")

# Overwrite existing
pcase.export_case("ieee14", ".", overwrite=True)
```

**Python CLI:**
```bash
# Export to current directory
pcase export ieee14 .

# Export to project directory
pcase export ieee14 ./my-project/cases

# Overwrite existing
pcase export ieee14 . --overwrite
```

**MATLAB:**
```matlab
% Export to current directory
pcase.export_case('ieee14', '.')              % → ./ieee14/

% Export to project directory
pcase.export_case('ieee14', './my-project/cases')

% Overwrite existing
pcase.export_case('ieee14', '.', 'overwrite', true)
```

### Typical Workflow

```bash
# 1. Export a test case to your project
pcase export ieee14 ./my-project

# 2. Modify the files locally
# Edit ./my-project/ieee14/ieee14.raw (change loads, add generators, etc.)

# 3. Use the modified version in your simulation
```

```julia
# Julia
using Powerful
using PowerFlowData

# Load your modified case
case = PowerFlowData.parse_network("./my-project/ieee14/ieee14.raw")
sys = SystemModel(case)
solve(ACPowerFlowProblem(sys), Newton())
```

```python
# Python with ANDES
import andes
ss = andes.load("./my-project/ieee14/ieee14.raw")
ss.PFlow.run()
```

```matlab
% MATLAB with Simulink
case = pcase.load('./my-project/ieee14');
% Open modified .slx model or load data
% open_system(case.file('simulink'))  % For future .slx support
```

**Benefits of exported cases:**
- Full control: modify any parameter
- Version control: track changes with Git
- Reproducibility: case files live with your analysis code
- Offline work: no network dependency after export

## Command-Line Interface (Python)

The `pcase` CLI helps manage cases and cache:

```bash
# List all available cases
pcase list

# Export a case to local directory
pcase export ieee14 .
pcase export ieee14 ./my-project --overwrite

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

**Bundle formats (OpenDSS):** For formats where a main file references additional files, use `includes` to list dependent files:

```toml
[[files]]
path = "Master.dss"
format = "opendss"
default = true
includes = ["LineCodes.dss", "Lines.dss", "Loads.dss", "LoadShape.csv"]

[[files]]
path = "Master_peak.dss"
format = "opendss"
variant = "peak"
includes = ["LineCodes.dss", "Lines.dss", "Loads_peak.dss", "LoadShape_peak.csv"]
```

When downloading remote cases, all files in `includes` are downloaded alongside the main file. Files appearing in multiple `includes` lists (like `LineCodes.dss` above) are automatically deduplicated and downloaded only once.

**When you need a manifest:**
- Multiple files of the same format (e.g., several DYR variants)
- Ambiguous extensions (`.m` could be MATPOWER or PSAT)
- Format version tracking (PSS/E v33 vs v34)
- Bundle formats with dependent files (OpenDSS)
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

## License

MIT
