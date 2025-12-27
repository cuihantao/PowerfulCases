# Cache management for PowerfulCases
# Handles downloading and caching of remote case files

using Downloads

"""
Default cache directory for downloaded cases.
"""
const DEFAULT_CACHE_DIR = joinpath(homedir(), ".powerfulcases")

"""
Global cache directory setting. Use `set_cache_dir()` to change.
"""
const CACHE_DIR = Ref{String}(DEFAULT_CACHE_DIR)

"""
    get_cache_dir() -> String

Get the current cache directory path.
"""
function get_cache_dir()
    CACHE_DIR[]
end

"""
    set_cache_dir(path::AbstractString)

Set the cache directory for downloaded cases.
Creates the directory if it doesn't exist.
"""
function set_cache_dir(path::AbstractString)
    CACHE_DIR[] = abspath(path)
    mkpath(CACHE_DIR[])
    CACHE_DIR[]
end

"""
    ensure_cache_dir() -> String

Ensure the cache directory exists and return its path.
"""
function ensure_cache_dir()
    dir = get_cache_dir()
    mkpath(dir)
    dir
end

"""
    get_cached_case_dir(name::AbstractString) -> String

Get the directory path for a cached case (may not exist yet).
"""
function get_cached_case_dir(name::AbstractString)
    joinpath(get_cache_dir(), name)
end

"""
    is_case_cached(name::AbstractString) -> Bool

Check if a case is already cached locally.
"""
function is_case_cached(name::AbstractString)
    dir = get_cached_case_dir(name)
    isdir(dir) && isfile(joinpath(dir, "manifest.toml"))
end

"""
    download_file(url::AbstractString, dest::AbstractString;
                  progress::Bool=true) -> String

Download a file from a URL to a destination path.
Returns the destination path.
"""
function download_file(url::AbstractString, dest::AbstractString; progress::Bool=true)
    mkpath(dirname(dest))
    if progress
        @info "Downloading: $url"
    end
    Downloads.download(url, dest)
    dest
end

"""
    clear_cache(name::Union{AbstractString, Nothing}=nothing)

Clear cached cases.
If `name` is provided, only clear that specific case.
If `name` is nothing, clear the entire cache.
"""
function clear_cache(name::Union{AbstractString, Nothing}=nothing)
    if name === nothing
        cache_dir = get_cache_dir()
        if isdir(cache_dir)
            rm(cache_dir; recursive=true)
            @info "Cleared entire cache at $cache_dir"
        end
    else
        case_dir = get_cached_case_dir(name)
        if isdir(case_dir)
            rm(case_dir; recursive=true)
            @info "Cleared cache for '$name'"
        else
            @warn "Case '$name' not found in cache"
        end
    end
end

"""
    list_cached_cases() -> Vector{String}

List all cases currently in the cache.
"""
function list_cached_cases()
    cache_dir = get_cache_dir()
    if !isdir(cache_dir)
        return String[]
    end

    cases = String[]
    for name in readdir(cache_dir)
        case_dir = joinpath(cache_dir, name)
        if isdir(case_dir) && isfile(joinpath(case_dir, "manifest.toml"))
            push!(cases, name)
        end
    end
    cases
end

"""
    cache_info() -> NamedTuple

Get information about the cache.
"""
function cache_info()
    cache_dir = get_cache_dir()
    cases = list_cached_cases()

    total_size = 0
    if isdir(cache_dir)
        for (root, _, files) in walkdir(cache_dir)
            for file in files
                total_size += filesize(joinpath(root, file))
            end
        end
    end

    (
        directory = cache_dir,
        exists = isdir(cache_dir),
        cases = cases,
        num_cases = length(cases),
        total_size_mb = round(total_size / 1024 / 1024; digits=2),
    )
end
