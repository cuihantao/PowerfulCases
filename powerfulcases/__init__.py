"""
powerfulcases - Test case data for power systems simulation

New API (Recommended):
    from powerfulcases import load, cases

    # Load a case (built-in, remote, or local directory)
    case = load("ieee14")
    case = load("/path/to/my/project")

    # Access files by format
    case.raw                                    # Default RAW file
    case.dyr                                    # Default DYR file
    file(case, "psse_raw")                  # Same as case.raw
    file(case, "psse_dyr", variant="genrou")  # Specific variant

    # Discovery
    cases()                    # All available cases
    formats(case)              # Available formats
    variants(case, "psse_dyr") # Variants for a format

    # Cache management (for remote cases)
    download("activsg70k")     # Pre-download large case
    clear("activsg70k")       # Remove from cache

Legacy API (Deprecated):
    case = ieee14()        # Still works, emits deprecation warning
    case.raw
    case.get_dyr("genrou")
"""

# New API exports
from .cases import (
    CaseBundle,
    load,
    file,
    cases,
    formats,
    variants,
    manifest,
    export_case,
)
from .cache import (
    get_cache_dir,
    set_cache_dir,
    clear,
    info,
)
from .registry import (
    download,
    list_remote_cases,
)

# Re-export main API
__all__ = [
    # Core
    "CaseBundle",
    "load",
    "file",
    "cases",
    "formats",
    "variants",
    "export_case",
    # Manifest
    "manifest",
    # Cache
    "get_cache_dir",
    "set_cache_dir",
    "clear",
    "info",
    # Remote
    "download",
    "list_remote_cases",
]

# Legacy API: Auto-generate deprecated case functions at import time
import sys as _sys
from .cases import _make_legacy_case_fn, CASES_DIR

_module = _sys.modules[__name__]

# Pre-defined legacy functions (already in cases.py)
from .cases import (
    ieee14,
    ieee39,
    ieee118,
    ACTIVSg2000,
    ACTIVSg10k,
    ACTIVSg70k,
    case5,
    case9,
    npcc,
    two_bus_branch,
    two_bus_transformer,
    ieee14_fault,
    ieee14_island,
    ieee39_nopq31,
    ieee39_rt,
)

# Add legacy case names to __all__
_legacy_cases = [
    "ieee14",
    "ieee39",
    "ieee118",
    "ACTIVSg2000",
    "ACTIVSg10k",
    "ACTIVSg70k",
    "case5",
    "case9",
    "npcc",
    "two_bus_branch",
    "two_bus_transformer",
    "ieee14_fault",
    "ieee14_island",
    "ieee39_nopq31",
    "ieee39_rt",
]
__all__.extend(_legacy_cases)

# Generate any additional case functions discovered at runtime
for _name in cases():
    if _name not in _legacy_cases and not hasattr(_module, _name):
        _fn = _make_legacy_case_fn(_name)
        setattr(_module, _name, _fn)
        __all__.append(_name)
