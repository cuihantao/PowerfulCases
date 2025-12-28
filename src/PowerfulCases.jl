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
export load, file, cases, list_files, formats, variants
export manifest
export download, clear, set_cache_dir, info
export CaseBundle, Manifest, FileEntry, Credits, Citation
export get_credits, get_license, get_authors, get_maintainers, get_citations, has_credits


const CASES_DIR = joinpath(@__DIR__, "..", "powerfulcases", "cases")

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

Base.propertynames(cb::CaseBundle) = (:name, :dir, :manifest, :is_remote, :raw, :dyr, formats(cb)...)

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

# Arguments
- `name_or_path`: Either a case name (e.g., "ieee14") or a path to a local directory

# Examples
```julia
# Built-in case
case = load("ieee14")

# Local directory
case = load("/path/to/my/project")
```
"""
function load(name_or_path::AbstractString)
    # Check if it's a path (contains / or \\ or is absolute)
    if isdir(name_or_path)
        return _load_local_case(name_or_path)
    end

    # Check if it's a known bundled case
    bundled_dir = joinpath(CASES_DIR, name_or_path)
    if isdir(bundled_dir)
        return _load_bundled_case(name_or_path, bundled_dir)
    end

    # Check if it's a remote case
    if is_remote_case(name_or_path)
        return _load_remote_case(name_or_path)
    end

    # Not found
    available = cases()
    error("Unknown case: '$name_or_path'. Available cases: $(join(available, ", "))")
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

function _load_remote_case(name::AbstractString)
    # Download if not cached
    if !is_case_cached(name)
        download(name)
    end

    dir = get_cached_case_dir(name)
    manifest_path = joinpath(dir, "manifest.toml")
    if isfile(manifest_path)
        manifest = parse_manifest(manifest_path)
    else
        manifest = infer_manifest(dir)
    end
    CaseBundle(name, dir, manifest, true)
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
      variant=f.variant, default=f.default) for f in cb.manifest.files]
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
    cases() -> Vector{String}

List all available case names (bundled + remote + cached).
"""
function cases()
    result = Set{String}()

    # Bundled cases
    if isdir(CASES_DIR)
        for entry in readdir(CASES_DIR)
            path = joinpath(CASES_DIR, entry)
            if isdir(path) && !startswith(entry, ".")
                push!(result, entry)
            end
        end
    end

    # Remote cases from registry
    for name in list_remote_cases()
        push!(result, name)
    end

    # Cached cases
    for name in list_cached_cases()
        push!(result, name)
    end

    sort(collect(result))
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
    # Support old flat structure for backwards compatibility
    parts = split(filename, '/')
    if length(parts) == 1
        name = replace(filename, r"\.(raw|dyr)$" => "")
        bundle_path = joinpath(CASES_DIR, name, filename)
        if isfile(bundle_path)
            return bundle_path
        end
    elseif length(parts) == 2 && parts[1] == "dyr"
        dyr_file = parts[2]
        name = replace(dyr_file, r"\.dyr$" => "")
        base_name = split(name, "_")[1]
        bundle_path = joinpath(CASES_DIR, base_name, dyr_file)
        if isfile(bundle_path)
            return bundle_path
        end
    end

    full_path = joinpath(CASES_DIR, filename)
    if isfile(full_path)
        return full_path
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
