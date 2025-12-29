"""
PowerfulCases - Test case data for power systems simulation

Provides IEEE test cases, synthetic grid cases, and dynamic model data files
with a bundle-based API for easy access.

# New API (Recommended)
```julia
using PowerfulCases

# Load a case (built-in, remote, or local directory)
case = load("ieee14")
case = load("/path/to/my/project")

# Access files by format
case.raw                                    # Default RAW file
case.dyr                                    # Default DYR file
file(case, :raw)                        # Same as case.raw
file(case, :raw, format_version="34")   # Specific PSS/E version
file(case, :dyr, variant="genrou")      # Specific variant

# Discovery
cases()                    # All available cases
list_files(case)                # Files with format info
formats(case)              # Available formats
variants(case, :dyr)       # Variants for a format

# Cache management (for remote cases)
download("activsg70k")     # Pre-download large case
clear("activsg70k")       # Remove from cache
```

# Legacy API (Deprecated)
```julia
case = ieee14()        # Still works, emits deprecation warning
case.raw               # Works
get_dyr(case, "genrou") # Works
```
"""
module PowerfulCases

using TOML
import Base: show

# Include submodules
include("manifest.jl")
include("cache.jl")
include("registry.jl")

# Re-export key functions from submodules
export load, file, cases, collections, list_files, formats, variants
export manifest
export download, clear, set_cache_dir, info
export export_case  # Export cases to local directory
export CaseBundle, Manifest, FileEntry, Credits, Citation
export get_credits, get_license, get_authors, get_maintainers, get_citations, has_credits


const CASES_DIR = joinpath(@__DIR__, "..", "powerfulcases", "cases")

# Progress reporting threshold for export operations
const PROGRESS_THRESHOLD_BYTES = 100 * 1024 * 1024  # 100 MB

"""
    CaseBundle

A bundle containing paths to a power system test case and its data files.

# Fields
- `name::String` - Case name (e.g., "ieee14")
- `dir::String` - Path to case directory
- `manifest::Manifest` - Parsed manifest with file metadata
- `is_remote::Bool` - True if loaded from remote cache
"""
struct CaseBundle
    name::String
    dir::String
    manifest::Manifest
    is_remote::Bool
end

# Property access for CaseBundle - convenience shortcuts
function Base.getproperty(cb::CaseBundle, prop::Symbol)
    if prop in (:name, :dir, :manifest, :is_remote)
        return getfield(cb, prop)
    elseif prop === :raw
        return file(cb, :psse_raw)
    elseif prop === :dyr
        path = file(cb, :psse_dyr; required=false)
        return path
    elseif prop === :matpower
        return file(cb, :matpower)
    elseif prop === :psat
        return file(cb, :psat)
    elseif prop === :collection
        # First check manifest
        manifest = getfield(cb, :manifest)
        if manifest.collection !== nothing
            return manifest.collection
        end
        # Infer from directory structure
        dir = getfield(cb, :dir)
        parent_name = basename(dirname(dir))
        return parent_name == "cases" ? nothing : parent_name
    elseif prop === :tags
        manifest = getfield(cb, :manifest)
        return manifest.tags
    else
        # Try as a format symbol
        try
            return file(cb, prop)
        catch e
            # Include original exception for debugging context
            error("CaseBundle has no property :$prop. Available formats: $(formats(cb)). Original error: $e")
        end
    end
end

Base.propertynames(cb::CaseBundle) = (:name, :dir, :manifest, :is_remote, :collection, :tags, :raw, :dyr, formats(cb)...)

# Functor syntax for backward compatibility: case("genrou") → file(case, :dyr, variant="genrou")
(cb::CaseBundle)(variant::String) = file(cb, :psse_dyr; variant=variant)

# Pretty printing for CaseBundle (matches Python `pcase info` output)
function show(io::IO, ::MIME"text/plain", cb::CaseBundle)
    println(io, "Case: ", cb.name)
    println(io, "Directory: ", cb.dir)
    println(io, "Remote: ", cb.is_remote)

    m = cb.manifest
    if !isempty(m.description)
        println(io, "Description: ", m.description)
    end
    if m.data_version !== nothing && !isempty(m.data_version)
        println(io, "Data version: ", m.data_version)
    end

    # Credits section
    if m.credits !== nothing
        println(io)
        println(io, "Credits:")
        if m.credits.license !== nothing
            println(io, "  License: ", m.credits.license)
        end
        if !isempty(m.credits.authors)
            println(io, "  Authors: ", join(m.credits.authors, ", "))
        end
        if !isempty(m.credits.maintainers)
            println(io, "  Maintainers: ", join(m.credits.maintainers, ", "))
        end
        if !isempty(m.credits.citations)
            println(io, "  Citations:")
            for cit in m.credits.citations
                println(io, "    - ", cit.text)
                if cit.doi !== nothing
                    println(io, "      DOI: ", cit.doi)
                end
            end
        end
    end

    # Files section
    println(io)
    println(io, "Files:")
    for f in m.files
        parts = String["  $(f.path)", "($(f.format))"]
        if f.format_version !== nothing
            push!(parts, "v$(f.format_version)")
        end
        if f.variant !== nothing
            push!(parts, "[$(f.variant)]")
        end
        if f.default
            push!(parts, "*default*")
        end
        println(io, join(parts, " "))
    end
end

# Compact show for CaseBundle
function show(io::IO, cb::CaseBundle)
    print(io, "CaseBundle(\"", cb.name, "\")")
end

"""
    load(name_or_path::AbstractString) -> CaseBundle

Load a case bundle by name or path.

The API automatically searches all collections (bundled + remote) to find the case.
Users don't need to know which collection a case belongs to.

# Arguments
- `name_or_path`: Either a case name (e.g., "ieee14"), a collection/case path
                  (e.g., "ieee-transmission/ieee14"), or a path to a local directory

# Examples
```julia
# Searches all collections
case = load("ieee14")

# Explicit collection
case = load("ieee-transmission/ieee14")

# Local directory
case = load("/path/to/my/project")
```
"""
function load(name_or_path::AbstractString)
    # 1. Check if it's a directory path
    if isdir(name_or_path)
        return _load_local_case(name_or_path)
    end

    # 2. Check if it's an absolute path that doesn't exist
    if isabspath(name_or_path)
        error("Directory not found: $name_or_path")
    end

    # 3. Check if it's a collection/case path (relative path with /)
    if occursin("/", name_or_path)
        parts = split(name_or_path, "/")

        # Validate each path component for security (skip empty parts from split)
        for part in parts
            if !isempty(part)
                _validate_path_component(part)
            end
        end

        bundled_dir = joinpath(CASES_DIR, parts...)

        # Verify resolved path is within CASES_DIR
        if isdir(bundled_dir) && startswith(abspath(bundled_dir), abspath(CASES_DIR))
            return _load_bundled_case(parts[end], bundled_dir)
        end

        # Also check if it's a remote case with collection/case format
        if is_remote_case(name_or_path)
            return _load_remote_case(name_or_path)
        end
    end

    # 4. Collect ALL matches from both bundled and remote sources
    matches = []  # List of (source_type, collection, location) tuples

    # Bundled matches
    case_dirs = _find_case_in_collections(name_or_path)
    for case_dir in case_dirs
        parent_dir = dirname(case_dir)
        coll_name = parent_dir == CASES_DIR ? "(root)" : basename(parent_dir)
        push!(matches, ("bundled", coll_name, case_dir))
    end

    # Remote matches
    remote_path = _find_remote_case_by_name(name_or_path)
    if remote_path !== nothing
        # Extract collection from remote_path (e.g., "collection/case")
        if occursin("/", remote_path)
            remote_coll = split(remote_path, "/")[1]
        else
            remote_coll = "(root)"
        end
        push!(matches, ("remote", remote_coll, remote_path))
    end

    # Check for ambiguity across ALL sources
    if length(matches) > 1
        sources = ["$(source_type):$(coll)" for (source_type, coll, _) in matches]
        error("Ambiguous case name '$name_or_path' found in multiple locations: $sources. " *
              "Use 'collection/case' format to specify.")
    end

    # Load the single match
    if length(matches) == 1
        source_type, _, location = matches[1]
        if source_type == "bundled"
            return _load_bundled_case(name_or_path, location)
        else  # remote
            return _load_remote_case(location)
        end
    end

    # Not found
    available = cases()
    error("Unknown case: '$name_or_path'. Available: $(join(available[1:min(10, end)], ", "))")
end

function _load_bundled_case(name::AbstractString, dir::AbstractString)
    manifest_path = joinpath(dir, "manifest.toml")
    if isfile(manifest_path)
        manifest = parse_manifest(manifest_path)
    else
        manifest = infer_manifest(dir)
    end
    CaseBundle(name, dir, manifest, false)
end

function _load_local_case(dir::AbstractString)
    manifest_path = joinpath(dir, "manifest.toml")
    if isfile(manifest_path)
        manifest = parse_manifest(manifest_path)
    else
        manifest = infer_manifest(dir)
    end
    CaseBundle(basename(dir), abspath(dir), manifest, false)
end

function _load_remote_case(name_or_path::AbstractString)
    """
    Load a remote case, downloading if necessary.

    Args:
        name_or_path: Case name or collection/case path (e.g., "synthetic/ACTIVSg2000")
    """
    # Download if not cached
    if !is_case_cached(name_or_path)
        download(name_or_path)
    end

    dir = get_cached_case_dir(name_or_path)
    manifest_path = joinpath(dir, "manifest.toml")
    if isfile(manifest_path)
        manifest = parse_manifest(manifest_path)
    else
        manifest = infer_manifest(dir)
    end

    # Extract case name from "collection/case_name" or use as-is
    if occursin("/", name_or_path)
        case_name = split(name_or_path, "/")[end]
    else
        case_name = name_or_path
    end

    CaseBundle(case_name, dir, manifest, true)
end

"""
    file(cb::CaseBundle, format::Symbol;
             format_version=nothing, variant=nothing, required=true) -> Union{String, Nothing}

Get the path to a file by format.

# Arguments
- `cb`: Case bundle
- `format`: Format symbol (e.g., :psse_raw, :psse_dyr, :matpower, :raw, :dyr)
- `format_version`: Optional format version (e.g., "33" for PSS/E v33)
- `variant`: Optional variant name (e.g., "genrou")
- `required`: If true (default), error if not found; if false, return nothing

# Examples
```julia
case = load("ieee14")
file(case, :raw)                        # Default RAW file
file(case, :dyr, variant="genrou")      # Specific variant
file(case, :raw, format_version="34")   # Specific PSS/E version
```
"""
function file(cb::CaseBundle, format::Symbol;
                  format_version::Union{String, Nothing}=nothing,
                  variant::Union{String, Nothing}=nothing,
                  required::Bool=true)
    # Normalize format aliases
    actual_format = _normalize_format(format)

    # Find matching file entry
    entry = file_entry(cb.manifest, actual_format;
                           format_version=format_version, variant=variant)

    if entry === nothing && variant === nothing && format_version === nothing
        # Try to find any file of this format (use default)
        entry = get_default_file(cb.manifest, actual_format)
    end

    if entry === nothing
        if required
            available = formats(cb)
            if variant !== nothing
                avail_variants = variants(cb, actual_format)
                error("File not found for format :$format with variant '$variant' in case '$(cb.name)'. Available variants: $(join(avail_variants, ", "))")
            elseif format_version !== nothing
                error("File not found for format :$format with version '$format_version' in case '$(cb.name)'. Available formats: $(join(available, ", "))")
            else
                error("File not found for format :$format in case '$(cb.name)'. Available formats: $(join(available, ", "))")
            end
        else
            return nothing
        end
    end

    joinpath(cb.dir, entry.path)
end

"""
Normalize format aliases to canonical format symbols.
"""
function _normalize_format(format::Symbol)
    if format === :raw
        return :psse_raw
    elseif format === :dyr
        return :psse_dyr
    else
        return format
    end
end

"""
    formats(cb::CaseBundle) -> Vector{Symbol}

List all formats available in a case bundle.
"""
function formats(cb::CaseBundle)
    formats(cb.manifest)
end

"""
    variants(cb::CaseBundle, format::Symbol) -> Vector{String}

List all variants available for a format in a case bundle.
"""
function variants(cb::CaseBundle, format::Symbol)
    actual_format = _normalize_format(format)
    variants(cb.manifest, actual_format)
end

"""
    list_files(cb::CaseBundle) -> Vector{NamedTuple}

List all files in a case bundle with their metadata.
"""
function list_files(cb::CaseBundle)
    [(path=f.path, format=f.format, format_version=f.format_version,
      variant=f.variant, default=f.default, includes=f.includes) for f in cb.manifest.files]
end

# ============================================================================
# Credits API
# ============================================================================

"""
    get_credits(cb::CaseBundle) -> Union{Credits, Nothing}

Get the credits/attribution information for a case bundle.
Returns `nothing` if no credits are defined.
"""
function get_credits(cb::CaseBundle)
    cb.manifest.credits
end

"""
    has_credits(cb::CaseBundle) -> Bool

Check if a case bundle has credits information.
"""
function has_credits(cb::CaseBundle)
    cb.manifest.credits !== nothing
end

"""
    get_license(cb::CaseBundle) -> Union{String, Nothing}

Get the SPDX license identifier for a case bundle.
Returns `nothing` if not specified.
"""
function get_license(cb::CaseBundle)
    cb.manifest.credits === nothing ? nothing : cb.manifest.credits.license
end

"""
    get_authors(cb::CaseBundle) -> Vector{String}

Get the list of original data authors/creators.
Returns an empty vector if not specified.
"""
function get_authors(cb::CaseBundle)
    cb.manifest.credits === nothing ? String[] : cb.manifest.credits.authors
end

"""
    get_maintainers(cb::CaseBundle) -> Vector{String}

Get the list of PowerfulCases maintainers.
Returns an empty vector if not specified.
"""
function get_maintainers(cb::CaseBundle)
    cb.manifest.credits === nothing ? String[] : cb.manifest.credits.maintainers
end

"""
    get_citations(cb::CaseBundle) -> Vector{Citation}

Get the list of publications to cite when using this case.
Returns an empty vector if not specified.
"""
function get_citations(cb::CaseBundle)
    cb.manifest.credits === nothing ? Citation[] : cb.manifest.credits.citations
end

"""
    _validate_path_component(component::AbstractString)

Validate that a path component is safe (no directory traversal).

Throws ArgumentError if component contains unsafe characters or patterns.
"""
function _validate_path_component(component::AbstractString)
    isempty(component) && throw(ArgumentError("Path component cannot be empty"))

    # Check for directory traversal
    if occursin(r"[/\\]", component) || occursin("..", component)
        throw(ArgumentError("Invalid path component: '$component' contains path separators or '..'"))
    end

    # Check for absolute paths
    if startswith(component, "/") || (Sys.iswindows() && occursin(r"^[A-Za-z]:", component))
        throw(ArgumentError("Invalid path component: '$component' is an absolute path"))
    end

    return true
end

"""
    _find_case_in_collections(case_name::AbstractString) -> Vector{String}

Search all collection directories for a case by name.
Returns list of all matching case directory paths.

Throws ArgumentError if case_name contains unsafe characters.
"""
function _find_case_in_collections(case_name::AbstractString)
    # Validate case name for security
    _validate_path_component(case_name)

    matches = String[]
    isdir(CASES_DIR) || return matches

    # Check top-level (legacy flat structure)
    top_level_case = joinpath(CASES_DIR, case_name)
    if isdir(top_level_case)
        # Verify resolved path is within CASES_DIR
        if startswith(abspath(top_level_case), abspath(CASES_DIR))
            push!(matches, top_level_case)
        end
    end

    # Search collection subdirectories
    for coll_dir in readdir(CASES_DIR)
        coll_path = joinpath(CASES_DIR, coll_dir)
        isdir(coll_path) && !startswith(coll_dir, ".") || continue

        case_dir = joinpath(coll_path, case_name)
        if isdir(case_dir)
            # Verify resolved path is within collection
            if startswith(abspath(case_dir), abspath(coll_path))
                push!(matches, case_dir)
            end
        end
    end

    matches
end

"""
    _find_remote_case_by_name(case_name::AbstractString) -> Union{String, Nothing}

Search remote_cases for a case by name, return full collection/case path.
"""
function _find_remote_case_by_name(case_name::AbstractString)
    remote_cases = list_remote_cases()
    matches = String[]

    for remote_path in remote_cases
        # Extract case name from "collection/case_name" or flat "case_name" format
        if occursin("/", remote_path)
            parts = split(remote_path, "/")
            remote_case_name = parts[end]
        else
            remote_case_name = remote_path
        end

        if remote_case_name == case_name
            push!(matches, remote_path)
        end
    end

    if length(matches) > 1
        error("Ambiguous remote case '$case_name' found in multiple collections: $matches")
    end

    length(matches) > 0 ? matches[1] : nothing
end

"""
    cases(; collection=nothing, tag=nothing) -> Vector{String}

List all available case names with optional filtering.

# Arguments
- `collection`: Filter by collection name (e.g., "ieee-transmission")
- `tag`: Filter by tag (e.g., "benchmark")

# Examples
```julia
cases()                                # All cases
cases(collection="ieee-transmission")  # Filter by collection
cases(tag="benchmark")                 # Filter by tag
```
"""
function cases(;
    collection::Union{String, Nothing}=nothing,
    tag::Union{String, Nothing}=nothing
)
    result = Dict{String, Tuple{Union{String, Nothing}, Vector{String}}}()

    # Bundled cases - scan for manifests recursively
    if isdir(CASES_DIR)
        for (root, dirs, files) in walkdir(CASES_DIR)
            if "manifest.toml" in files
                case_dir = root
                case_name = basename(case_dir)
                startswith(case_name, ".") && continue

                # Determine collection
                coll_dir = dirname(case_dir)
                coll_name = coll_dir == CASES_DIR ? nothing : basename(coll_dir)

                # Parse manifest for tags
                try
                    manifest_path = joinpath(case_dir, "manifest.toml")
                    manifest = parse_manifest(manifest_path)
                    tags = manifest.tags
                    result[case_name] = (coll_name, tags)
                catch
                    result[case_name] = (coll_name, String[])
                end
            end
        end

        # Cases without manifests (inferred)
        for coll_dir in readdir(CASES_DIR)
            coll_path = joinpath(CASES_DIR, coll_dir)
            isdir(coll_path) && !startswith(coll_dir, ".") || continue

            for case_dir in readdir(coll_path)
                case_path = joinpath(coll_path, case_dir)
                if isdir(case_path) && !haskey(result, case_dir)
                    result[case_dir] = (coll_dir, String[])
                end
            end
        end
    end

    # Remote cases from registry - extract case names
    for remote_path in list_remote_cases()
        if occursin("/", remote_path)
            parts = split(remote_path, "/")
            case_name = parts[end]
            coll_name = length(parts) > 1 ? parts[1] : nothing
        else
            case_name = remote_path
            coll_name = nothing
        end

        if !haskey(result, case_name)
            result[case_name] = (coll_name, String[])
        end
    end

    # Cached cases
    for name in list_cached_cases()
        if !haskey(result, name)
            result[name] = (nothing, String[])
        end
    end

    # Apply filters
    filtered = String[]
    for (name, (coll, tag_list)) in result
        if collection !== nothing && coll != collection
            continue
        end
        if tag !== nothing && !(tag in tag_list)
            continue
        end
        push!(filtered, name)
    end

    sort(filtered)
end

"""
    collections() -> Vector{String}

List all available collection names.

# Examples
```julia
collections()  # ['ieee-distribution', 'ieee-transmission', 'matpower', 'synthetic', 'test']
```
"""
function collections()
    result = Set{String}()

    if isdir(CASES_DIR)
        for entry in readdir(CASES_DIR)
            path = joinpath(CASES_DIR, entry)
            if isdir(path) && !startswith(entry, ".")
                # Check if it has a collection.toml or contains case subdirectories
                if isfile(joinpath(path, "collection.toml"))
                    push!(result, entry)
                elseif any(isdir(joinpath(path, e)) for e in readdir(path) if !startswith(e, "."))
                    push!(result, entry)
                end
            end
        end
    end

    sort(collect(result))
end

# ============================================================================
# Export API
# ============================================================================

"""
    export_case(case_name::AbstractString, dest::AbstractString; overwrite::Bool=false) -> String

Export a case bundle to a local directory.

The case will be copied to `dest/case_name/` as a subdirectory. All files in the case
directory are included (RAW, DYR variants, manifest, etc.).

# Arguments
- `case_name`: Name of case (e.g., "ieee14") or path to local directory
- `dest`: Destination directory (case will be copied to `dest/case_name/`)
- `overwrite`: Allow overwriting existing directory (default: false)

# Returns
- Path to exported directory

# Examples
```julia
# Export bundled case to current directory
export_case("ieee14", ".")              # → ./ieee14/

# Export remote case (downloads first if needed)
export_case("ACTIVSg70k", "./cases")    # → ./cases/ACTIVSg70k/

# Export with overwrite
export_case("ieee14", "."; overwrite=true)

# Export local directory (copies it)
export_case("/path/to/my-case", "./backup")
```

# Notes
- Bundled cases: copied from package installation
- Remote cases: downloaded to cache first, then copied
- Local directories: copied recursively
- All files in the case directory are included (symlinks are followed)
- manifest.toml is always copied if it exists
- Progress is shown for files larger than 100 MB
- Files are copied preserving directory structure; no path traversal outside destination
"""
function export_case(case_name::AbstractString, dest::AbstractString; overwrite::Bool=false)
    # Load the case (triggers download if needed for remote cases)
    case = load(case_name)

    # Determine destination: dest/case_name/
    dest_dir = joinpath(abspath(dest), case.name)

    # Check if destination exists
    if isdir(dest_dir) && !overwrite
        error("Directory exists: $dest_dir\nUse overwrite=true to replace existing directory")
    end

    # Calculate total size for progress reporting
    total_size = 0
    file_list = String[]
    for (root, _, files) in walkdir(case.dir)
        for file in files
            filepath = joinpath(root, file)
            push!(file_list, filepath)
            total_size += filesize(filepath)
        end
    end

    # Show progress if size exceeds threshold
    show_progress = total_size > PROGRESS_THRESHOLD_BYTES

    if show_progress
        @info "Exporting $(case.name) ($(round(total_size / 1024 / 1024; digits=2)) MB)..."
    end

    # Remove existing directory if overwrite is true
    if isdir(dest_dir) && overwrite
        rm(dest_dir; recursive=true)
    end

    # Copy the entire directory
    cp(case.dir, dest_dir; force=overwrite)

    # Count files
    num_files = length(file_list)
    size_mb = round(total_size / 1024 / 1024; digits=2)

    @info "Exported $(case.name) → $dest_dir\nCopied $num_files files ($(size_mb) MB)"

    dest_dir
end

# ============================================================================
# Legacy API (Deprecated) - Backward compatibility
# ============================================================================

"""
    get_dyr(cb::CaseBundle, variant::String) -> String

Get the path to a DYR variant file. Convenience function.
"""
function get_dyr(cb::CaseBundle, variant::String)
    file(cb, :psse_dyr; variant=variant)
end

"""
    list_dyr_variants(cb::CaseBundle) -> Vector{String}

List available DYR variants for a case.
"""
function list_dyr_variants(cb::CaseBundle)
    variants(cb, :psse_dyr)
end

"""
    path(filename::String) -> String

[DEPRECATED] Direct file path access. Use load() instead.
"""
function path(filename::String)
    Base.depwarn(
        "PowerfulCases.path() is deprecated. Use load(\"casename\").raw instead.",
        :path
    )
    # Try to extract case name and use new load() API
    name = replace(filename, r"\.(raw|dyr)$" => "")

    try
        # Try loading with new API (searches all collections)
        case = load(name)

        # Check if it's a .raw or .dyr file
        if endswith(filename, ".raw")
            return case.raw
        elseif endswith(filename, ".dyr")
            return case.dyr
        else
            # Try to find the file in the case directory
            file_path = joinpath(case.dir, filename)
            if isfile(file_path)
                return file_path
            end
        end
    catch
        # Fall through to error
    end

    error("Case file not found: $filename. Use load() to access cases.")
end

# ============================================================================
# Deprecated case accessor functions (ieee14(), ieee39(), etc.)
# ============================================================================

# Track if deprecation warning has been shown for each case
const _DEPRECATION_WARNED = Set{Symbol}()

function _create_deprecated_case(name::Symbol)
    name_str = string(name)

    # Show deprecation warning once per case
    if !(name in _DEPRECATION_WARNED)
        push!(_DEPRECATION_WARNED, name)
        @warn """
PowerfulCases.$name_str() is deprecated. Use load("$name_str") instead.

Old API:
  case = $name_str()
  case.raw

New API:
  case = load("$name_str")
  case.raw
""" maxlog=1
    end

    # Return CaseBundle directly (no wrapper needed)
    load(name_str)
end

# Pre-generate for known cases at compile time
for name in [:ieee14, :ieee39, :ieee118, :ACTIVSg2000,
             :ACTIVSg10k, :ACTIVSg70k,
             :case5, :case9, :npcc, :two_bus_branch, :two_bus_transformer,
             :ieee14_fault, :ieee14_island, :ieee39_nopq31, :ieee39_rt]
    name_str = string(name)
    @eval begin
        """
            $($name_str)() -> CaseBundle

        [DEPRECATED] Get the $($name_str) test case bundle.
        Use `load("$($name_str)")` instead.
        """
        $name() = _create_deprecated_case($(QuoteNode(name)))
        export $name
    end
end

# Export legacy API for backward compatibility
export get_dyr, list_dyr_variants, path

end # module
