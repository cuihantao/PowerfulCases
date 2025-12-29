# Registry for remote PowerfulCases
# Manages the list of available remote cases and their download URLs.
#
# The registry.toml file defines which cases are remote (not bundled in wheels).

using TOML

"""
Size threshold in bytes for bundled vs remote cases.
Cases larger than this are not bundled and must be downloaded.
"""
const SIZE_THRESHOLD_BYTES = 2 * 1024 * 1024  # 2 MB

"""
Path to local registry file bundled with the package.
"""
function bundled_registry_path()
    joinpath(@__DIR__, "..", "registry.toml")
end

"""
Path to cached registry file.
"""
function cached_registry_path()
    joinpath(get_cache_dir(), "registry.toml")
end

"""
    Registry

Contains metadata about available remote cases.
"""
struct Registry
    remote_cases::Vector{String}
    base_url::String
    version::String
end

function Registry()
    Registry(String[], "", "0.0.0")
end

"""
    parse_registry(path::AbstractString) -> Registry

Parse a registry.toml file.
"""
function parse_registry(path::AbstractString)
    data = TOML.parsefile(path)

    version = get(data, "version", "0.0.0")
    base_url = get(data, "base_url", "")
    remote_cases = get(data, "remote_cases", String[])

    Registry(remote_cases, base_url, version)
end

"""
Global registry instance.
"""
const REGISTRY = Ref{Union{Registry, Nothing}}(nothing)

"""
    load_registry(; refresh::Bool=false) -> Registry

Load the case registry. Uses cached version if available,
falls back to bundled registry.

# Arguments
- `refresh`: If true, reload the registry from disk
"""
function load_registry(; refresh::Bool=false)
    if !refresh && REGISTRY[] !== nothing
        return REGISTRY[]
    end

    # Try cached registry first
    cached_path = cached_registry_path()
    if !refresh && isfile(cached_path)
        try
            REGISTRY[] = parse_registry(cached_path)
            return REGISTRY[]
        catch e
            @warn "Failed to parse cached registry, using bundled" exception=e
        end
    end

    # Fall back to bundled registry
    bundled_path = bundled_registry_path()
    if isfile(bundled_path)
        REGISTRY[] = parse_registry(bundled_path)
        return REGISTRY[]
    end

    # No registry available, return empty
    REGISTRY[] = Registry()
    REGISTRY[]
end

"""
    list_remote_cases() -> Vector{String}

List all cases available in the remote registry.
"""
function list_remote_cases()
    registry = load_registry()
    sort(registry.remote_cases)
end

"""
    is_remote_case(name::AbstractString) -> Bool

Check if a case name is available in the remote registry.
"""
function is_remote_case(name::AbstractString)
    registry = load_registry()
    name in registry.remote_cases
end

"""
    get_case_base_url(name::AbstractString) -> String

Get the base URL for a remote case's files.
"""
function get_case_base_url(name::AbstractString)
    registry = load_registry()
    "$(registry.base_url)/$(name)"
end

"""
    download(name::AbstractString; force::Bool=false) -> String

Download a case from the remote registry.
Downloads the manifest.toml first, then all files listed in the manifest.

Returns the path to the downloaded case directory.
"""
function download(name::AbstractString; force::Bool=false)
    registry = load_registry()

    if !(name in registry.remote_cases)
        available = join(sort(registry.remote_cases), ", ")
        error("Unknown remote case: '$name'. Available: $available")
    end

    if !force && is_case_cached(name)
        @info "Case '$name' already cached at $(get_cached_case_dir(name))"
        return get_cached_case_dir(name)
    end

    base_url = "$(registry.base_url)/$(name)"
    case_dir = get_cached_case_dir(name)
    ensure_cache_dir()
    mkpath(case_dir)

    # Step 1: Download manifest.toml
    manifest_url = "$(base_url)/manifest.toml"
    manifest_path = joinpath(case_dir, "manifest.toml")
    @info "Downloading manifest: $manifest_url"
    download_file(manifest_url, manifest_path; progress=false)

    # Step 2: Parse manifest to get file list
    manifest_data = TOML.parsefile(manifest_path)
    files = get(manifest_data, "files", [])

    if isempty(files)
        @warn "No files listed in manifest for '$name'"
        return case_dir
    end

    # Step 3: Download each file and its includes
    downloaded = Set{String}()  # Track downloaded files to avoid duplicates
    for file_entry in files
        file_path = get(file_entry, "path", nothing)
        if file_path === nothing
            continue
        end

        # Download the main file
        if file_path ∉ downloaded
            file_url = "$(base_url)/$(file_path)"
            dest_path = joinpath(case_dir, file_path)
            mkpath(dirname(dest_path))
            @info "Downloading: $file_path"
            download_file(file_url, dest_path; progress=false)
            push!(downloaded, file_path)
        end

        # Download includes (additional files bundled with this entry)
        includes = get(file_entry, "includes", String[])
        for include_path in includes
            if include_path ∉ downloaded
                include_url = "$(base_url)/$(include_path)"
                dest_path = joinpath(case_dir, include_path)
                mkpath(dirname(dest_path))
                @info "Downloading: $include_path"
                download_file(include_url, dest_path; progress=false)
                push!(downloaded, include_path)
            end
        end
    end

    @info "Downloaded case '$name' to $case_dir"
    return case_dir
end
