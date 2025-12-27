# Manifest types and parsing for PowerfulCases
# Handles manifest.toml files that describe case bundles

using TOML

"""
Known file formats with their typical extensions.
Ambiguous extensions (like .m) require manifest to specify format.
"""
const FORMAT_EXTENSIONS = Dict{Symbol, Vector{String}}(
    :psse_raw => [".raw"],
    :psse_dyr => [".dyr"],
    :matpower => [".m"],
    :psat => [".m"],
    :json => [".json"],
    :xlsx => [".xlsx"],
)

"""
Extensions that are unambiguous (map to exactly one format).
"""
const UNAMBIGUOUS_EXTENSIONS = Dict{String, Symbol}(
    ".raw" => :psse_raw,
    ".dyr" => :psse_dyr,
    ".json" => :json,
    ".xlsx" => :xlsx,
)

"""
Extensions that are ambiguous (could be multiple formats).
"""
const AMBIGUOUS_EXTENSIONS = Set([".m"])

"""
    FileEntry

Describes a single file in a case bundle.

# Fields
- `path::String`: Relative path to the file within the bundle directory
- `format::Symbol`: File format (e.g., :psse_raw, :psse_dyr, :matpower, :psat)
- `format_version::Union{String, Nothing}`: Format-specific version (e.g., "33" for PSS/E v33)
- `variant::Union{String, Nothing}`: Variant name (e.g., "genrou" for different dynamic models)
- `default::Bool`: Whether this is the default file for its format
"""
struct FileEntry
    path::String
    format::Symbol
    format_version::Union{String, Nothing}
    variant::Union{String, Nothing}
    default::Bool
end

function FileEntry(path::String, format::Symbol;
                   format_version::Union{String, Nothing}=nothing,
                   variant::Union{String, Nothing}=nothing,
                   default::Bool=false)
    FileEntry(path, format, format_version, variant, default)
end

"""
    Citation

A citation/publication reference for a case bundle.

# Fields
- `text::String`: Formatted citation text
- `doi::Union{String, Nothing}`: Digital Object Identifier (optional)
"""
struct Citation
    text::String
    doi::Union{String, Nothing}
end

function Citation(text::String; doi::Union{String, Nothing}=nothing)
    Citation(text, doi)
end

"""
    Credits

Attribution and licensing information for a case bundle.

# Fields
- `license::Union{String, Nothing}`: SPDX license identifier (e.g., "CC0-1.0", "CC-BY-4.0")
- `authors::Vector{String}`: Original data creators
- `maintainers::Vector{String}`: PowerfulCases maintainers
- `citations::Vector{Citation}`: Publications to cite when using this data
"""
struct Credits
    license::Union{String, Nothing}
    authors::Vector{String}
    maintainers::Vector{String}
    citations::Vector{Citation}
end

function Credits(;
    license::Union{String, Nothing}=nothing,
    authors::Vector{String}=String[],
    maintainers::Vector{String}=String[],
    citations::Vector{Citation}=Citation[]
)
    Credits(license, authors, maintainers, citations)
end

"""
    Manifest

Describes a case bundle and its contents.

# Fields
- `name::String`: Case name (e.g., "ieee14")
- `description::String`: Human-readable description
- `data_version::Union{String, Nothing}`: When this data was created/updated
- `files::Vector{FileEntry}`: List of files in the bundle
- `credits::Union{Credits, Nothing}`: Attribution and licensing info (optional)
"""
struct Manifest
    name::String
    description::String
    data_version::Union{String, Nothing}
    files::Vector{FileEntry}
    credits::Union{Credits, Nothing}
end

function Manifest(name::String;
                  description::String="",
                  data_version::Union{String, Nothing}=nothing,
                  files::Vector{FileEntry}=FileEntry[],
                  credits::Union{Credits, Nothing}=nothing)
    Manifest(name, description, data_version, files, credits)
end

"""
    parse_manifest(path::AbstractString) -> Manifest

Parse a manifest.toml file and return a Manifest object.
"""
function parse_manifest(path::AbstractString)
    data = TOML.parsefile(path)

    name = get(data, "name", basename(dirname(path)))
    description = get(data, "description", "")
    data_version = get(data, "data_version", nothing)

    files = FileEntry[]
    for file_data in get(data, "files", [])
        file_path = file_data["path"]
        format = Symbol(file_data["format"])
        format_version = get(file_data, "format_version", nothing)
        variant = get(file_data, "variant", nothing)
        default = get(file_data, "default", false)

        push!(files, FileEntry(file_path, format; format_version, variant, default))
    end

    # Parse credits section if present
    credits = nothing
    if haskey(data, "credits")
        credits_data = data["credits"]
        license = get(credits_data, "license", nothing)
        authors = convert(Vector{String}, get(credits_data, "authors", String[]))
        maintainers = convert(Vector{String}, get(credits_data, "maintainers", String[]))

        citations = Citation[]
        for cit_data in get(credits_data, "citations", [])
            text = cit_data["text"]
            doi = get(cit_data, "doi", nothing)
            push!(citations, Citation(text; doi))
        end

        credits = Credits(; license, authors, maintainers, citations)
    end

    Manifest(name; description, data_version, files, credits)
end

"""
    infer_manifest(dir::AbstractString) -> Manifest

Infer a manifest from directory contents by scanning for known file types.
Errors if ambiguous extensions (.m files) are found without a manifest.
"""
function infer_manifest(dir::AbstractString)
    name = basename(dir)
    files = FileEntry[]
    ambiguous_files = String[]

    for filename in readdir(dir)
        filepath = joinpath(dir, filename)
        isfile(filepath) || continue

        ext = lowercase(splitext(filename)[2])

        if ext in AMBIGUOUS_EXTENSIONS
            push!(ambiguous_files, filename)
        elseif haskey(UNAMBIGUOUS_EXTENSIONS, ext)
            format = UNAMBIGUOUS_EXTENSIONS[ext]
            # First file of each format is the default
            is_default = !any(f -> f.format == format, files)
            push!(files, FileEntry(filename, format; default=is_default))
        end
        # Ignore unknown extensions
    end

    if !isempty(ambiguous_files)
        error("""
Cannot determine format for .m files in $dir
Found: $(join(ambiguous_files, ", "))

These could be MATPOWER or PSAT format. Please create a manifest:
  Julia:  PowerfulCases.create_manifest("$dir")
  Python: powerfulcases create-manifest $dir

Then edit manifest.toml to specify the correct format for each .m file.
""")
    end

    Manifest(name; files)
end

"""
    write_manifest(manifest::Manifest, path::AbstractString)

Write a Manifest to a TOML file.
"""
function write_manifest(manifest::Manifest, path::AbstractString)
    data = Dict{String, Any}(
        "name" => manifest.name,
    )

    if !isempty(manifest.description)
        data["description"] = manifest.description
    end

    if manifest.data_version !== nothing
        data["data_version"] = manifest.data_version
    end

    if !isempty(manifest.files)
        data["files"] = [
            begin
                file_dict = Dict{String, Any}(
                    "path" => f.path,
                    "format" => string(f.format),
                )
                if f.format_version !== nothing
                    file_dict["format_version"] = f.format_version
                end
                if f.variant !== nothing
                    file_dict["variant"] = f.variant
                end
                if f.default
                    file_dict["default"] = true
                end
                file_dict
            end
            for f in manifest.files
        ]
    end

    # Write credits section if present
    if manifest.credits !== nothing
        credits = manifest.credits
        credits_dict = Dict{String, Any}()

        if credits.license !== nothing
            credits_dict["license"] = credits.license
        end
        if !isempty(credits.authors)
            credits_dict["authors"] = credits.authors
        end
        if !isempty(credits.maintainers)
            credits_dict["maintainers"] = credits.maintainers
        end
        if !isempty(credits.citations)
            credits_dict["citations"] = [
                begin
                    cit_dict = Dict{String, Any}("text" => c.text)
                    if c.doi !== nothing
                        cit_dict["doi"] = c.doi
                    end
                    cit_dict
                end
                for c in credits.citations
            ]
        end

        if !isempty(credits_dict)
            data["credits"] = credits_dict
        end
    end

    open(path, "w") do io
        TOML.print(io, data)
    end
end

"""
    create_manifest(dir::AbstractString) -> String

Create a manifest.toml file for a case directory.
Returns the path to the created manifest.

If ambiguous files (.m) are found, creates a template manifest with
placeholder format that must be edited manually.
"""
function create_manifest(dir::AbstractString)
    isdir(dir) || error("Directory does not exist: $dir")

    manifest_path = joinpath(dir, "manifest.toml")
    name = basename(dir)
    files = FileEntry[]
    ambiguous_files = String[]

    for filename in readdir(dir)
        filepath = joinpath(dir, filename)
        isfile(filepath) || continue
        filename == "manifest.toml" && continue  # Skip existing manifest

        ext = lowercase(splitext(filename)[2])

        if ext in AMBIGUOUS_EXTENSIONS
            push!(ambiguous_files, filename)
        elseif haskey(UNAMBIGUOUS_EXTENSIONS, ext)
            format = UNAMBIGUOUS_EXTENSIONS[ext]
            is_default = !any(f -> f.format == format, files)
            push!(files, FileEntry(filename, format; default=is_default))
        end
    end

    # Add ambiguous files with placeholder format
    for filename in ambiguous_files
        # Default to matpower, user must edit if it's psat
        push!(files, FileEntry(filename, :matpower_or_psat))
    end

    manifest = Manifest(name; files)
    write_manifest(manifest, manifest_path)

    if !isempty(ambiguous_files)
        @warn """
Created manifest with ambiguous .m files: $(join(ambiguous_files, ", "))
Please edit $manifest_path and change 'matpower_or_psat' to either 'matpower' or 'psat'.
"""
    else
        @info "Created manifest: $manifest_path"
    end

    manifest_path
end

"""
    get_default_file(manifest::Manifest, format::Symbol) -> Union{FileEntry, Nothing}

Get the default file for a given format, or nothing if not found.
"""
function get_default_file(manifest::Manifest, format::Symbol)
    # First try to find an explicit default
    for f in manifest.files
        if f.format == format && f.default
            return f
        end
    end
    # Fall back to first file of that format
    for f in manifest.files
        if f.format == format
            return f
        end
    end
    nothing
end

"""
    get_file_entry(manifest::Manifest, format::Symbol;
                   format_version=nothing, variant=nothing) -> Union{FileEntry, Nothing}

Get a specific file entry matching the criteria.
"""
function get_file_entry(manifest::Manifest, format::Symbol;
                        format_version::Union{String, Nothing}=nothing,
                        variant::Union{String, Nothing}=nothing)
    for f in manifest.files
        f.format == format || continue

        if format_version !== nothing && f.format_version != format_version
            continue
        end

        if variant !== nothing
            # Special case: "default" matches files with default=true and no explicit variant
            if variant == "default"
                if !(f.variant === nothing && f.default)
                    continue
                end
            elseif f.variant != variant
                continue
            end
        end

        return f
    end
    nothing
end

"""
    list_formats(manifest::Manifest) -> Vector{Symbol}

List all unique formats available in the manifest.
"""
function list_formats(manifest::Manifest)
    unique([f.format for f in manifest.files])
end

"""
    list_variants(manifest::Manifest, format::Symbol) -> Vector{String}

List all variants available for a given format.
"""
function list_variants(manifest::Manifest, format::Symbol)
    variants = String[]
    for f in manifest.files
        if f.format == format
            if f.variant !== nothing
                push!(variants, f.variant)
            elseif f.default
                push!(variants, "default")
            end
        end
    end
    unique(variants)
end
