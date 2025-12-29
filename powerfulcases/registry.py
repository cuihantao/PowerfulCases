"""
Registry for remote PowerfulCases.
Manages the list of available remote cases and their download URLs.

The registry.toml file is the SINGLE SOURCE OF TRUTH for which cases
are remote (not bundled in the Python wheel).
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Set

try:
    import tomllib
except ImportError:
    import tomli as tomllib

from .cache import (
    get_cache_dir,
    ensure_cache_dir,
    download_file,
    get_cached_case_dir,
    is_case_cached,
)

# Size threshold in bytes for bundled vs remote cases
SIZE_THRESHOLD_BYTES = 2 * 1024 * 1024  # 2 MB


def bundled_registry_path() -> Path:
    """Path to local registry file bundled with the package."""
    return Path(__file__).parent.parent / "registry.toml"


def cached_registry_path() -> Path:
    """Path to cached registry file."""
    return get_cache_dir() / "registry.toml"


@dataclass
class Registry:
    """Contains metadata about available remote cases."""

    remote_cases: List[str] = field(default_factory=list)
    base_url: str = ""
    version: str = "0.0.0"


def parse_registry(path: Path) -> Registry:
    """
    Parse a registry.toml file.

    Args:
        path: Path to the registry file

    Returns:
        Registry object
    """
    with open(path, "rb") as f:
        data = tomllib.load(f)

    version = data.get("version", "0.0.0")
    base_url = data.get("base_url", "")
    remote_cases = data.get("remote_cases", [])

    return Registry(remote_cases=remote_cases, base_url=base_url, version=version)


# Global registry instance
_registry: Optional[Registry] = None


def load_registry(refresh: bool = False) -> Registry:
    """
    Load the case registry. Uses cached version if available,
    falls back to bundled registry.

    Args:
        refresh: If True, reload the registry from disk

    Returns:
        Registry object
    """
    global _registry

    if not refresh and _registry is not None:
        return _registry

    # Try cached registry first
    cached_path = cached_registry_path()
    if not refresh and cached_path.is_file():
        try:
            _registry = parse_registry(cached_path)
            return _registry
        except Exception as e:
            import warnings

            warnings.warn(f"Failed to parse cached registry, using bundled: {e}")

    # Fall back to bundled registry
    bundled_path = bundled_registry_path()
    if bundled_path.is_file():
        _registry = parse_registry(bundled_path)
        return _registry

    # No registry available, return empty
    _registry = Registry()
    return _registry


def list_remote_cases() -> List[str]:
    """
    List all cases available in the remote registry.

    Returns:
        Sorted list of case names
    """
    registry = load_registry()
    return sorted(registry.remote_cases)


def is_remote_case(name: str) -> bool:
    """
    Check if a case name is available in the remote registry.

    Args:
        name: Case name

    Returns:
        True if case is in remote registry
    """
    registry = load_registry()
    return name in registry.remote_cases


def get_case_base_url(name: str) -> str:
    """
    Get the base URL for a remote case's files.

    Args:
        name: Case name

    Returns:
        URL prefix for the case (e.g., "https://.../cases/ACTIVSg70k")
    """
    registry = load_registry()
    return f"{registry.base_url}/{name}"


def download(name: str, force: bool = False) -> Path:
    """
    Download a case from the remote registry.

    Downloads the manifest.toml first, then all files listed in the manifest.

    Args:
        name: Case name to download
        force: If True, re-download even if cached

    Returns:
        Path to the downloaded case directory

    Raises:
        ValueError: If case not in registry
    """
    registry = load_registry()

    if name not in registry.remote_cases:
        available = ", ".join(sorted(registry.remote_cases))
        raise ValueError(f"Unknown remote case: '{name}'. Available: {available}")

    if not force and is_case_cached(name):
        print(f"Case '{name}' already cached at {get_cached_case_dir(name)}")
        return get_cached_case_dir(name)

    base_url = f"{registry.base_url}/{name}"
    case_dir = get_cached_case_dir(name)
    ensure_cache_dir()
    case_dir.mkdir(parents=True, exist_ok=True)

    # Step 1: Download manifest.toml
    manifest_url = f"{base_url}/manifest.toml"
    manifest_path = case_dir / "manifest.toml"
    print(f"Downloading manifest: {manifest_url}")
    download_file(manifest_url, manifest_path, progress=False)

    # Step 2: Parse manifest to get file list
    with open(manifest_path, "rb") as f:
        manifest_data = tomllib.load(f)

    files = manifest_data.get("files", [])
    if not files:
        print(f"Warning: No files listed in manifest for '{name}'")
        return case_dir

    # Step 3: Download each file and its includes
    downloaded: Set[str] = set()  # Track downloaded files to avoid duplicates
    for file_entry in files:
        file_path = file_entry.get("path")
        if not file_path:
            continue

        # Download the main file
        if file_path not in downloaded:
            file_url = f"{base_url}/{file_path}"
            dest_path = case_dir / file_path
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            print(f"Downloading: {file_path}")
            download_file(file_url, dest_path, progress=False)
            downloaded.add(file_path)

        # Download includes (additional files bundled with this entry)
        includes = file_entry.get("includes", [])
        for include_path in includes:
            if include_path not in downloaded:
                include_url = f"{base_url}/{include_path}"
                dest_path = case_dir / include_path
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                print(f"Downloading: {include_path}")
                download_file(include_url, dest_path, progress=False)
                downloaded.add(include_path)

    print(f"Downloaded case '{name}' to {case_dir}")
    return case_dir
