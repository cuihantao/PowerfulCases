"""
Manifest types and parsing for PowerfulCases.
Handles manifest.toml files that describe case bundles.
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Any, Set
import warnings

try:
    import tomllib
except ImportError:
    import tomli as tomllib

import toml  # For writing TOML files


# Known file formats with their typical extensions
FORMAT_EXTENSIONS: Dict[str, List[str]] = {
    "psse_raw": [".raw"],
    "psse_dyr": [".dyr"],
    "matpower": [".m"],
    "psat": [".m"],
    "json": [".json"],
    "andes": [".xlsx"],
    "opendss": [".dss"],
}

# Extensions that are unambiguous (map to exactly one format)
UNAMBIGUOUS_EXTENSIONS: Dict[str, str] = {
    ".raw": "psse_raw",
    ".dyr": "psse_dyr",
    ".dss": "opendss"
}

# Extensions that are ambiguous (could be multiple formats)
AMBIGUOUS_EXTENSIONS: Set[str] = {".m", ".xlsx", ".json"}


@dataclass
class FileEntry:
    """
    Describes a single file in a case bundle.

    Attributes:
        path: Relative path to the file within the bundle directory
        format: File format (e.g., "psse_raw", "psse_dyr", "matpower", "psat")
        format_version: Format-specific version (e.g., "33" for PSS/E v33)
        variant: Variant name (e.g., "genrou" for different dynamic models)
        default: Whether this is the default file for its format
        includes: Additional files to download with this file (for bundle formats like OpenDSS)
    """

    path: str
    format: str
    format_version: Optional[str] = None
    variant: Optional[str] = None
    default: bool = False
    includes: List[str] = field(default_factory=list)


@dataclass
class Citation:
    """
    A citation/publication reference for a case bundle.

    Attributes:
        text: Formatted citation text
        doi: Digital Object Identifier (optional)
    """

    text: str
    doi: Optional[str] = None


@dataclass
class Credits:
    """
    Attribution and licensing information for a case bundle.

    Attributes:
        license: SPDX license identifier (e.g., "CC0-1.0", "CC-BY-4.0")
        authors: Original data creators
        maintainers: PowerfulCases maintainers
        citations: Publications to cite when using this data
    """

    license: Optional[str] = None
    authors: List[str] = field(default_factory=list)
    maintainers: List[str] = field(default_factory=list)
    citations: List[Citation] = field(default_factory=list)


@dataclass
class Manifest:
    """
    Describes a case bundle and its contents.

    Attributes:
        name: Case name (e.g., "ieee14")
        description: Human-readable description
        data_version: When this data was created/updated
        files: List of files in the bundle
        credits: Attribution and licensing info (optional)
    """

    name: str
    description: str = ""
    data_version: Optional[str] = None
    files: List[FileEntry] = field(default_factory=list)
    credits: Optional[Credits] = None


def parse_manifest(path: Path) -> Manifest:
    """
    Parse a manifest.toml file and return a Manifest object.

    Args:
        path: Path to the manifest.toml file (can be str or Path)

    Returns:
        Parsed Manifest object
    """
    path = Path(path)  # Ensure it's a Path object
    with open(path, "rb") as f:
        data = tomllib.load(f)

    name = data.get("name", path.parent.name)
    description = data.get("description", "")
    data_version = data.get("data_version", None)

    files = []
    for file_data in data.get("files", []):
        files.append(
            FileEntry(
                path=file_data["path"],
                format=file_data["format"],
                format_version=file_data.get("format_version"),
                variant=file_data.get("variant"),
                default=file_data.get("default", False),
                includes=file_data.get("includes", []),
            )
        )

    # Parse credits section if present
    credits = None
    if "credits" in data:
        credits_data = data["credits"]
        citations = []
        for cit_data in credits_data.get("citations", []):
            citations.append(
                Citation(
                    text=cit_data["text"],
                    doi=cit_data.get("doi"),
                )
            )
        credits = Credits(
            license=credits_data.get("license"),
            authors=credits_data.get("authors", []),
            maintainers=credits_data.get("maintainers", []),
            citations=citations,
        )

    return Manifest(
        name=name, description=description, data_version=data_version, files=files, credits=credits
    )


def infer_manifest(directory: Path) -> Manifest:
    """
    Infer a manifest from directory contents by scanning for known file types.
    Raises an error if ambiguous extensions (.m files) are found without a manifest.

    Args:
        directory: Path to the case directory

    Returns:
        Inferred Manifest object

    Raises:
        ValueError: If ambiguous extensions are found
    """
    name = directory.name
    files = []
    ambiguous_files = []

    # Track which formats have a default already
    formats_with_default: Set[str] = set()

    for filepath in directory.iterdir():
        if not filepath.is_file():
            continue

        ext = filepath.suffix.lower()

        if ext in AMBIGUOUS_EXTENSIONS:
            ambiguous_files.append(filepath.name)
        elif ext in UNAMBIGUOUS_EXTENSIONS:
            fmt = UNAMBIGUOUS_EXTENSIONS[ext]
            is_default = fmt not in formats_with_default
            if is_default:
                formats_with_default.add(fmt)
            files.append(FileEntry(path=filepath.name, format=fmt, default=is_default))
        # Ignore unknown extensions

    if ambiguous_files:
        raise ValueError(
            f"""Cannot determine format for .m files in {directory}
Found: {', '.join(ambiguous_files)}

These could be MATPOWER or PSAT format. Please create a manifest:
  Julia:  PowerfulCases.manifest("{directory}")
  Python: powerfulcases create-manifest {directory}

Then edit manifest.toml to specify the correct format for each .m file.
"""
        )

    return Manifest(name=name, files=files)


def write_manifest(manifest: Manifest, path: Path) -> None:
    """
    Write a Manifest to a TOML file.

    Args:
        manifest: Manifest object to write
        path: Path to write the manifest.toml file
    """
    data: Dict[str, Any] = {"name": manifest.name}

    if manifest.description:
        data["description"] = manifest.description

    if manifest.data_version:
        data["data_version"] = manifest.data_version

    if manifest.files:
        files_data = []
        for f in manifest.files:
            file_dict: Dict[str, Any] = {
                "path": f.path,
                "format": f.format,
            }
            if f.format_version:
                file_dict["format_version"] = f.format_version
            if f.variant:
                file_dict["variant"] = f.variant
            if f.default:
                file_dict["default"] = True
            if f.includes:
                file_dict["includes"] = f.includes
            files_data.append(file_dict)
        data["files"] = files_data

    # Write credits section if present
    if manifest.credits is not None:
        credits = manifest.credits
        credits_dict: Dict[str, Any] = {}

        if credits.license:
            credits_dict["license"] = credits.license
        if credits.authors:
            credits_dict["authors"] = credits.authors
        if credits.maintainers:
            credits_dict["maintainers"] = credits.maintainers
        if credits.citations:
            citations_data = []
            for c in credits.citations:
                cit_dict: Dict[str, Any] = {"text": c.text}
                if c.doi:
                    cit_dict["doi"] = c.doi
                citations_data.append(cit_dict)
            credits_dict["citations"] = citations_data

        if credits_dict:
            data["credits"] = credits_dict

    with open(path, "w") as f:
        toml.dump(data, f)


def manifest(directory: Path) -> Path:
    """
    Create a manifest.toml file for a case directory.

    If ambiguous files (.m) are found, creates a template manifest with
    placeholder format that must be edited manually.

    Args:
        directory: Path to the case directory

    Returns:
        Path to the created manifest.toml file
    """
    directory = Path(directory)
    if not directory.is_dir():
        raise ValueError(f"Directory does not exist: {directory}")

    manifest_path = directory / "manifest.toml"
    name = directory.name
    files = []
    ambiguous_files = []

    formats_with_default: Set[str] = set()

    for filepath in directory.iterdir():
        if not filepath.is_file():
            continue
        if filepath.name == "manifest.toml":
            continue

        ext = filepath.suffix.lower()

        if ext in AMBIGUOUS_EXTENSIONS:
            ambiguous_files.append(filepath.name)
        elif ext in UNAMBIGUOUS_EXTENSIONS:
            fmt = UNAMBIGUOUS_EXTENSIONS[ext]
            is_default = fmt not in formats_with_default
            if is_default:
                formats_with_default.add(fmt)
            files.append(FileEntry(path=filepath.name, format=fmt, default=is_default))

    # Add ambiguous files with placeholder format
    for filename in ambiguous_files:
        files.append(FileEntry(path=filename, format="matpower_or_psat"))

    manifest = Manifest(name=name, files=files)
    write_manifest(manifest, manifest_path)

    if ambiguous_files:
        warnings.warn(
            f"Created manifest with ambiguous .m files: {', '.join(ambiguous_files)}\n"
            f"Please edit {manifest_path} and change 'matpower_or_psat' to either 'matpower' or 'psat'."
        )
    else:
        print(f"Created manifest: {manifest_path}")

    return manifest_path


def get_default_file(manifest: Manifest, format: str) -> Optional[FileEntry]:
    """
    Get the default file for a given format, or None if not found.

    Args:
        manifest: Manifest to search
        format: Format to find (e.g., "psse_raw")

    Returns:
        FileEntry or None
    """
    # First try to find an explicit default
    for f in manifest.files:
        if f.format == format and f.default:
            return f
    # Fall back to first file of that format
    for f in manifest.files:
        if f.format == format:
            return f
    return None


def file_entry(
    manifest: Manifest,
    format: str,
    format_version: Optional[str] = None,
    variant: Optional[str] = None,
) -> Optional[FileEntry]:
    """
    Get a specific file entry matching the criteria.

    Args:
        manifest: Manifest to search
        format: Format to find
        format_version: Optional format version filter
        variant: Optional variant filter

    Returns:
        FileEntry or None
    """
    for f in manifest.files:
        if f.format != format:
            continue
        if format_version is not None and f.format_version != format_version:
            continue
        if variant is not None:
            # Special case: "default" matches files with default=True and no explicit variant
            if variant == "default":
                if not (f.variant is None and f.default):
                    continue
            elif f.variant != variant:
                continue
        return f
    return None


def formats(manifest: Manifest) -> List[str]:
    """
    List all unique formats available in the manifest.

    Args:
        manifest: Manifest to search

    Returns:
        List of format strings
    """
    return list(set(f.format for f in manifest.files))


def variants(manifest: Manifest, format: str) -> List[str]:
    """
    List all variants available for a given format.

    Args:
        manifest: Manifest to search
        format: Format to filter by

    Returns:
        List of variant names
    """
    result = []
    for f in manifest.files:
        if f.format == format:
            if f.variant is not None:
                result.append(f.variant)
            elif f.default:
                result.append("default")
    return list(set(result))
