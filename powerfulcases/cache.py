"""
Cache management for PowerfulCases.
Handles downloading and caching of remote case files.
"""

import os
import shutil
import urllib.request
from pathlib import Path
from typing import List, NamedTuple, Optional

# Default cache directory for downloaded cases
DEFAULT_CACHE_DIR = Path.home() / ".powerfulcases"

# Global cache directory setting
_cache_dir: Path = DEFAULT_CACHE_DIR


def get_cache_dir() -> Path:
    """Get the current cache directory path."""
    return _cache_dir


def set_cache_dir(path: Path) -> Path:
    """
    Set the cache directory for downloaded cases.
    Creates the directory if it doesn't exist.

    Args:
        path: New cache directory path

    Returns:
        The absolute path to the cache directory
    """
    global _cache_dir
    _cache_dir = Path(path).absolute()
    _cache_dir.mkdir(parents=True, exist_ok=True)
    return _cache_dir


def ensure_cache_dir() -> Path:
    """
    Ensure the cache directory exists and return its path.

    Returns:
        Path to the cache directory
    """
    cache_dir = get_cache_dir()
    cache_dir.mkdir(parents=True, exist_ok=True)
    return cache_dir


def get_cached_case_dir(name: str) -> Path:
    """
    Get the directory path for a cached case (may not exist yet).

    Args:
        name: Case name

    Returns:
        Path to the case directory in cache
    """
    return get_cache_dir() / name


def is_case_cached(name: str) -> bool:
    """
    Check if a case is already cached locally.

    Args:
        name: Case name

    Returns:
        True if case is cached with a manifest
    """
    case_dir = get_cached_case_dir(name)
    return case_dir.is_dir() and (case_dir / "manifest.toml").is_file()


def download_file(url: str, dest: Path, progress: bool = True) -> Path:
    """
    Download a file from a URL to a destination path.

    Args:
        url: URL to download from
        dest: Destination file path
        progress: Whether to print progress

    Returns:
        The destination path
    """
    dest.parent.mkdir(parents=True, exist_ok=True)
    if progress:
        print(f"Downloading: {url}")

    urllib.request.urlretrieve(url, dest)
    return dest


def clear(name: Optional[str] = None) -> None:
    """
    Clear cached cases.

    Args:
        name: If provided, only clear that specific case.
              If None, clear the entire cache.
    """
    if name is None:
        cache_dir = get_cache_dir()
        if cache_dir.is_dir():
            shutil.rmtree(cache_dir)
            print(f"Cleared entire cache at {cache_dir}")
    else:
        case_dir = get_cached_case_dir(name)
        if case_dir.is_dir():
            shutil.rmtree(case_dir)
            print(f"Cleared cache for '{name}'")
        else:
            print(f"Case '{name}' not found in cache")


def list_cached_cases() -> List[str]:
    """
    List all cases currently in the cache.

    Returns:
        List of case names
    """
    cache_dir = get_cache_dir()
    if not cache_dir.is_dir():
        return []

    cases = []
    for entry in cache_dir.iterdir():
        if entry.is_dir() and (entry / "manifest.toml").is_file():
            cases.append(entry.name)
    return sorted(cases)


class CacheInfo(NamedTuple):
    """Information about the cache."""

    directory: Path
    exists: bool
    cases: List[str]
    num_cases: int
    total_size_mb: float


def info() -> CacheInfo:
    """
    Get information about the cache.

    Returns:
        CacheInfo named tuple with cache details
    """
    cache_dir = get_cache_dir()
    cases = list_cached_cases()

    total_size = 0
    if cache_dir.is_dir():
        for root, _, files in os.walk(cache_dir):
            for file in files:
                total_size += os.path.getsize(os.path.join(root, file))

    return CacheInfo(
        directory=cache_dir,
        exists=cache_dir.is_dir(),
        cases=cases,
        num_cases=len(cases),
        total_size_mb=round(total_size / 1024 / 1024, 2),
    )
