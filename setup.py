"""
Setup script that reads registry.toml to generate exclude list dynamically.

All other configuration is in pyproject.toml. This file only handles
the dynamic exclude-package-data based on remote_cases in registry.toml.
"""

from pathlib import Path

try:
    import tomllib
except ImportError:
    import tomli as tomllib

from setuptools import setup

# Read registry.toml to get remote cases
registry_path = Path(__file__).parent / "registry.toml"
with open(registry_path, "rb") as f:
    registry = tomllib.load(f)

remote_cases = registry.get("remote_cases", [])

# Generate exclude patterns for remote cases
exclude_patterns = [f"cases/{name}/*" for name in remote_cases]

setup(
    exclude_package_data={
        "powerfulcases": exclude_patterns,
    },
)
