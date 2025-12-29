"""
PowerfulCases - Power systems test case data management.

New API (Recommended):
    from powerfulcases import load, cases

    case = load("ieee14")
    case = load("/path/to/my/project")

    case.raw                               # Default RAW file
    case.dyr                               # Default DYR file
    file(case, "psse_raw")             # Same as case.raw
    file(case, "psse_dyr", variant="genrou")  # Specific variant

Legacy API (Deprecated):
    from powerfulcases import ieee14

    case = ieee14()  # Emits deprecation warning
    case.raw
    case.get_dyr("genrou")
"""

import warnings
from pathlib import Path
from typing import Optional, List, Dict, Any, NamedTuple

from .manifest import (
    Manifest,
    FileEntry,
    Credits,
    Citation,
    parse_manifest,
    infer_manifest,
    get_default_file,
    file_entry,
    formats as _formats,
    variants as _variants,
    manifest,
)
from .cache import (
    get_cache_dir,
    set_cache_dir,
    is_case_cached,
    get_cached_case_dir,
    list_cached_cases,
    clear,
    info,
)
from .registry import (
    is_remote_case,
    download as _download_remote,
    list_remote_cases,
)

# Cases directory is inside the package for proper wheel distribution
CASES_DIR = Path(__file__).parent / "cases"

# Progress reporting threshold for export operations (100 MB)
PROGRESS_THRESHOLD_BYTES = 100 * 1024 * 1024


class FileInfo(NamedTuple):
    """Information about a file in a case bundle."""
    path: str
    format: str
    format_version: Optional[str]
    variant: Optional[str]
    default: bool
    includes: List[str]


class CaseBundle:
    """
    A bundle containing paths to a power system test case and its data files.

    Attributes:
        name: Case name (e.g., "ieee14")
        dir: Path to the case directory
        manifest: Parsed manifest with file metadata
        is_remote: True if loaded from remote cache

    Properties:
        raw: Path to the default RAW file
        dyr: Path to the default DYR file (or None)
        matpower: Path to the MATPOWER file (if available)
    """

    def __init__(self, name: str, directory: Path, manifest: Manifest, is_remote: bool = False):
        """
        Initialize a CaseBundle.

        Args:
            name: Case name
            directory: Path to the case directory
            manifest: Parsed manifest
            is_remote: Whether this was loaded from remote cache
        """
        self.name = name
        self.dir = str(directory)
        self.manifest = manifest
        self.is_remote = is_remote

    @property
    def raw(self) -> str:
        """Get the path to the default RAW file."""
        return file(self, "psse_raw")

    @property
    def dyr(self) -> Optional[str]:
        """Get the path to the default DYR file, or None if not available."""
        return file(self, "psse_dyr", required=False)

    @property
    def matpower(self) -> str:
        """Get the path to the MATPOWER file."""
        return file(self, "matpower")

    @property
    def psat(self) -> str:
        """Get the path to the PSAT file."""
        return file(self, "psat")

    # Credits API
    @property
    def credits(self) -> Optional[Credits]:
        """Get the credits/attribution information for this case, or None if not defined."""
        return self.manifest.credits

    def has_credits(self) -> bool:
        """Check if this case has credits information."""
        return self.manifest.credits is not None

    @property
    def license(self) -> Optional[str]:
        """Get the SPDX license identifier, or None if not specified."""
        return self.manifest.credits.license if self.manifest.credits else None

    @property
    def authors(self) -> List[str]:
        """Get the list of original data authors/creators."""
        return self.manifest.credits.authors if self.manifest.credits else []

    @property
    def maintainers(self) -> List[str]:
        """Get the list of PowerfulCases maintainers."""
        return self.manifest.credits.maintainers if self.manifest.credits else []

    @property
    def citations(self) -> List[Citation]:
        """Get the list of publications to cite when using this case."""
        return self.manifest.credits.citations if self.manifest.credits else []

    # Legacy API methods for backward compatibility
    def get_dyr(self, variant: str) -> str:
        """
        [Legacy API] Get the path to a DYR variant file.

        Args:
            variant: Variant name (e.g., "genrou")

        Returns:
            Path to the variant DYR file
        """
        return file(self, "psse_dyr", variant=variant)

    def list_dyr_variants(self) -> List[str]:
        """
        [Legacy API] List available DYR variants for this case.

        Returns:
            List of variant names
        """
        return variants(self, "psse_dyr")

    def list_files(self) -> List[FileInfo]:
        """
        List all files in the case bundle with their metadata.

        Returns:
            List of FileInfo named tuples
        """
        return [
            FileInfo(
                path=f.path,
                format=f.format,
                format_version=f.format_version,
                variant=f.variant,
                default=f.default,
                includes=f.includes,
            )
            for f in self.manifest.files
        ]

    def __repr__(self) -> str:
        return f"CaseBundle({self.name!r})"

    # Functor for legacy API: case("genrou")
    def __call__(self, variant: str) -> str:
        """Shorthand for get_dyr(variant)."""
        return self.get_dyr(variant)


def load(name_or_path: str) -> CaseBundle:
    """
    Load a case bundle by name or path.

    Args:
        name_or_path: Either a case name (e.g., "ieee14") or a path to a local directory

    Returns:
        CaseBundle object

    Examples:
        case = load("ieee14")        # Built-in case
        case = load("/path/to/dir")  # Local directory
    """
    path = Path(name_or_path)

    # Check if it's a directory path
    if path.is_dir():
        return _load_local_case(path)

    # Check if it's a known bundled case
    bundled_dir = CASES_DIR / name_or_path
    if bundled_dir.is_dir():
        return _load_bundled_case(name_or_path, bundled_dir)

    # Check if it's a remote case
    if is_remote_case(name_or_path):
        return _load_remote_case(name_or_path)

    # Not found
    available = cases()
    raise ValueError(
        f"Unknown case: '{name_or_path}'. Available cases: {', '.join(available)}"
    )


def _load_bundled_case(name: str, directory: Path) -> CaseBundle:
    """Load a bundled case from the package."""
    manifest_path = directory / "manifest.toml"
    if manifest_path.is_file():
        manifest = parse_manifest(manifest_path)
    else:
        manifest = infer_manifest(directory)
    return CaseBundle(name, directory, manifest, is_remote=False)


def _load_local_case(directory: Path) -> CaseBundle:
    """Load a case from a local directory."""
    manifest_path = directory / "manifest.toml"
    if manifest_path.is_file():
        manifest = parse_manifest(manifest_path)
    else:
        manifest = infer_manifest(directory)
    return CaseBundle(directory.name, directory.absolute(), manifest, is_remote=False)


def _load_remote_case(name: str) -> CaseBundle:
    """Load a remote case, downloading if necessary."""
    if not is_case_cached(name):
        _download_remote(name)

    directory = get_cached_case_dir(name)
    manifest_path = directory / "manifest.toml"
    if manifest_path.is_file():
        manifest = parse_manifest(manifest_path)
    else:
        manifest = infer_manifest(directory)
    return CaseBundle(name, directory, manifest, is_remote=True)


def file(
    case: CaseBundle,
    format: str,
    format_version: Optional[str] = None,
    variant: Optional[str] = None,
    required: bool = True,
) -> Optional[str]:
    """
    Get the path to a file by format.

    Args:
        case: Case bundle
        format: Format name (e.g., "psse_raw", "psse_dyr", "matpower", "raw", "dyr")
        format_version: Optional format version (e.g., "33" for PSS/E v33)
        variant: Optional variant name (e.g., "genrou")
        required: If True, raise error if not found; if False, return None

    Returns:
        Path to the file, or None if not found and not required

    Examples:
        file(case, "psse_raw")                       # Default RAW file
        file(case, "psse_dyr", variant="genrou")     # Specific variant
        file(case, "psse_raw", format_version="34")  # Specific version
    """
    # Normalize format aliases
    actual_format = _normalize_format(format)

    # Find matching file entry
    entry = file_entry(case.manifest, actual_format, format_version, variant)

    if entry is None and variant is None and format_version is None:
        # Try to find default
        entry = get_default_file(case.manifest, actual_format)

    if entry is None:
        if required:
            available = formats(case)
            if variant is not None:
                var_list = variants(case, actual_format)
                raise FileNotFoundError(
                    f"File not found for format '{format}' with variant '{variant}' "
                    f"in case '{case.name}'. Available variants: {', '.join(var_list)}"
                )
            elif format_version is not None:
                raise FileNotFoundError(
                    f"File not found for format '{format}' with version '{format_version}' "
                    f"in case '{case.name}'. Available formats: {', '.join(available)}"
                )
            else:
                raise FileNotFoundError(
                    f"File not found for format '{format}' in case '{case.name}'. "
                    f"Available formats: {', '.join(available)}"
                )
        else:
            return None

    return str(Path(case.dir) / entry.path)


def _normalize_format(format: str) -> str:
    """Normalize format aliases to canonical format names."""
    if format == "raw":
        return "psse_raw"
    elif format == "dyr":
        return "psse_dyr"
    return format


def formats(case: CaseBundle) -> List[str]:
    """
    List all formats available in a case bundle.

    Args:
        case: Case bundle

    Returns:
        List of format names
    """
    return _formats(case.manifest)


def variants(case: CaseBundle, format: str) -> List[str]:
    """
    List all variants available for a format in a case bundle.

    Args:
        case: Case bundle
        format: Format name

    Returns:
        List of variant names
    """
    actual_format = _normalize_format(format)
    return _variants(case.manifest, actual_format)


def cases() -> List[str]:
    """
    List all available case names (bundled + remote + cached).

    Returns:
        Sorted list of case names
    """
    result = set()

    # Bundled cases
    if CASES_DIR.is_dir():
        for entry in CASES_DIR.iterdir():
            if entry.is_dir() and not entry.name.startswith("."):
                result.add(entry.name)

    # Remote cases from registry
    for name in list_remote_cases():
        result.add(name)

    # Cached cases
    for name in list_cached_cases():
        result.add(name)

    return sorted(result)


# ============================================================================
# Export API
# ============================================================================

def export_case(case_name: str, dest: str, overwrite: bool = False) -> str:
    """
    Export a case bundle to a local directory.

    The case will be copied to dest/case_name/ as a subdirectory. All files in the case
    directory are included (RAW, DYR variants, manifest, etc.).

    Args:
        case_name: Name of case (e.g., "ieee14") or path to local directory
        dest: Destination directory (case will be copied to dest/case_name/)
        overwrite: Allow overwriting existing directory (default: False)

    Returns:
        Path to exported directory

    Examples:
        >>> export_case("ieee14", ".")
        './ieee14'

        >>> export_case("ACTIVSg70k", "./cases")
        './cases/ACTIVSg70k'

        >>> export_case("ieee14", ".", overwrite=True)
        './ieee14'

    Notes:
        - Bundled cases: copied from package installation
        - Remote cases: downloaded to cache first, then copied
        - Local directories: copied recursively
        - All files in the case directory are included (symlinks are followed)
        - manifest.toml is always copied if it exists
        - Progress is shown for files larger than 100 MB
        - Files are copied preserving directory structure; no path traversal outside destination
    """
    import shutil
    import os

    # Load the case (triggers download if needed for remote cases)
    case = load(case_name)

    # Determine destination: dest/case_name/
    dest_path = Path(dest).absolute()
    dest_dir = dest_path / case.name

    # Check if destination exists
    if dest_dir.exists() and not overwrite:
        raise FileExistsError(
            f"Directory exists: {dest_dir}\n"
            f"Use overwrite=True to replace existing directory"
        )

    # Calculate total size for progress reporting
    total_size = 0
    file_list = []
    case_path = Path(case.dir)

    for root, _, files in os.walk(case_path):
        for file in files:
            filepath = Path(root) / file
            file_list.append(filepath)
            total_size += filepath.stat().st_size

    # Show progress if size exceeds threshold
    show_progress = total_size > PROGRESS_THRESHOLD_BYTES

    if show_progress:
        size_mb = round(total_size / 1024 / 1024, 2)
        print(f"Exporting {case.name} ({size_mb} MB)...")

    # Remove existing directory if overwrite is True
    if dest_dir.exists() and overwrite:
        shutil.rmtree(dest_dir)

    # Copy the entire directory
    shutil.copytree(case_path, dest_dir)

    # Report success
    num_files = len(file_list)
    size_mb = round(total_size / 1024 / 1024, 2)
    print(f"Exported {case.name} → {dest_dir}")
    print(f"Copied {num_files} files ({size_mb} MB)")

    return str(dest_dir)


# ============================================================================
# Legacy API (Deprecated) - Backward compatibility
# ============================================================================

# Track which cases have shown deprecation warnings
_deprecation_warned: set = set()


def _make_legacy_case_fn(name: str):
    """
    Create a deprecated case accessor function.

    Args:
        name: Case name

    Returns:
        A function that returns a CaseBundle with deprecation warning
    """

    def fn() -> CaseBundle:
        if name not in _deprecation_warned:
            _deprecation_warned.add(name)
            warnings.warn(
                f"{name}() is deprecated. Use load('{name}') instead.\n\n"
                f"Old API:\n"
                f"  case = {name}()\n"
                f"  case.raw\n\n"
                f"New API:\n"
                f"  case = load('{name}')\n"
                f"  case.raw",
                DeprecationWarning,
                stacklevel=2,
            )
        return load(name)

    fn.__name__ = name
    fn.__doc__ = f"[DEPRECATED] Get the {name} test case bundle. Use load('{name}') instead."
    return fn


# Pre-generate accessor functions for known cases
ieee14 = _make_legacy_case_fn("ieee14")
ieee39 = _make_legacy_case_fn("ieee39")
ieee118 = _make_legacy_case_fn("ieee118")
ACTIVSg2000 = _make_legacy_case_fn("ACTIVSg2000")
ACTIVSg10k = _make_legacy_case_fn("ACTIVSg10k")
ACTIVSg70k = _make_legacy_case_fn("ACTIVSg70k")
case5 = _make_legacy_case_fn("case5")
case9 = _make_legacy_case_fn("case9")
npcc = _make_legacy_case_fn("npcc")
two_bus_branch = _make_legacy_case_fn("two_bus_branch")
two_bus_transformer = _make_legacy_case_fn("two_bus_transformer")
ieee14_fault = _make_legacy_case_fn("ieee14_fault")
ieee14_island = _make_legacy_case_fn("ieee14_island")
ieee39_nopq31 = _make_legacy_case_fn("ieee39_nopq31")
ieee39_rt = _make_legacy_case_fn("ieee39_rt")
