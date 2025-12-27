using Test
using PowerfulCases
using SHA
using Downloads

@testset "PowerfulCases" begin
    @testset "New API - load()" begin
        @testset "load with bundled case" begin
            case = load("ieee14")
            @test case.name == "ieee14"
            @test isfile(case.raw)
            @test endswith(case.raw, "ieee14.raw")
            @test case.dyr !== nothing
            @test isfile(case.dyr)
            @test case.is_remote == false
        end

        @testset "load with local directory" begin
            # Use ieee14 directory as a local path test
            cases_dir = joinpath(@__DIR__, "..", "powerfulcases", "cases", "ieee14")
            case = load(cases_dir)
            @test case.name == "ieee14"
            @test isfile(case.raw)
        end

        @testset "load unknown case error" begin
            @test_throws ErrorException load("nonexistent_case_xyz")
        end
    end

    @testset "New API - file()" begin
        case = load("ieee14")

        # Default format access
        raw_path = file(case, :raw)
        @test isfile(raw_path)
        @test endswith(raw_path, ".raw")

        dyr_path = file(case, :dyr)
        @test isfile(dyr_path)
        @test endswith(dyr_path, ".dyr")

        # Full format names also work
        raw_path2 = file(case, :psse_raw)
        @test raw_path == raw_path2

        # With variant
        genrou_path = file(case, :dyr, variant="genrou")
        @test isfile(genrou_path)
        @test occursin("genrou", genrou_path)

        # With "default" variant (special case)
        default_path = file(case, :dyr, variant="default")
        @test isfile(default_path)
        @test default_path == dyr_path

        # Required=false for missing format
        missing = file(case, :matpower, required=false)
        @test missing === nothing

        # Required=true (default) for missing format throws error
        @test_throws ErrorException file(case, :matpower)

        # Missing variant throws error
        @test_throws ErrorException file(case, :dyr, variant="nonexistent_variant")
    end

    @testset "New API - list functions" begin
        # cases returns strings now
        case_list = cases()
        @test "ieee14" in case_list
        @test "ieee39" in case_list
        @test length(case_list) > 5

        # formats
        case = load("ieee14")
        format_list = formats(case)
        @test :psse_raw in format_list
        @test :psse_dyr in format_list

        # variants
        variant_list = variants(case, :dyr)
        @test "genrou" in variant_list
        @test "default" in variant_list

        # variants with alias
        variant_list2 = variants(case, :psse_dyr)
        @test variant_list == variant_list2
    end

    @testset "New API - list_files with metadata" begin
        case = load("ieee14")
        files = list_files(case)
        @test !isempty(files)

        # Files are NamedTuples with metadata
        first_file = files[1]
        @test haskey(first_file, :path)
        @test haskey(first_file, :format)
        @test haskey(first_file, :default)
        @test haskey(first_file, :variant)
        @test haskey(first_file, :format_version)
    end

    @testset "CaseBundle property access" begin
        case = load("ieee14")

        # Standard properties
        @test case.name == "ieee14"
        @test isdir(case.dir)
        @test case.manifest isa PowerfulCases.Manifest
        @test case.is_remote == false

        # Convenience properties
        @test isfile(case.raw)
        @test case.dyr === nothing || isfile(case.dyr)

        # propertynames
        props = propertynames(case)
        @test :name in props
        @test :raw in props
        @test :dyr in props
    end

    @testset "Manifest parsing" begin
        using PowerfulCases: parse_manifest, Manifest, FileEntry

        cases_dir = joinpath(@__DIR__, "..", "powerfulcases", "cases", "ieee14")
        manifest_path = joinpath(cases_dir, "manifest.toml")

        manifest = parse_manifest(manifest_path)
        @test manifest.name == "ieee14"
        @test !isempty(manifest.files)
        @test manifest.description != ""

        # Check that files have correct format
        raw_files = filter(f -> f.format == :psse_raw, manifest.files)
        @test !isempty(raw_files)
        @test raw_files[1].default == true
    end

    @testset "Manifest inference" begin
        using PowerfulCases: infer_manifest

        # Create temp directory with unambiguous files
        mktempdir() do dir
            touch(joinpath(dir, "test.raw"))
            touch(joinpath(dir, "test.dyr"))

            manifest = infer_manifest(dir)
            @test manifest.name == basename(dir)
            @test length(manifest.files) == 2

            # Check formats were inferred correctly
            formats = [f.format for f in manifest.files]
            @test :psse_raw in formats
            @test :psse_dyr in formats

            # First file of each format should be default
            raw_file = filter(f -> f.format == :psse_raw, manifest.files)[1]
            @test raw_file.default == true
        end
    end

    @testset "Manifest inference with ambiguous files" begin
        using PowerfulCases: infer_manifest

        # Create temp directory with .m file (ambiguous)
        mktempdir() do dir
            touch(joinpath(dir, "case.m"))

            # Should throw error for ambiguous files
            @test_throws ErrorException infer_manifest(dir)
        end
    end

    @testset "Manifest writing" begin
        using PowerfulCases: write_manifest, parse_manifest, Manifest, FileEntry

        mktempdir() do dir
            # Create a manifest
            files = [
                FileEntry("test.raw", :psse_raw; default=true),
                FileEntry("test.dyr", :psse_dyr; variant="genrou"),
            ]
            manifest = Manifest("test_case"; description="Test", files=files)

            # Write it
            manifest_path = joinpath(dir, "manifest.toml")
            write_manifest(manifest, manifest_path)
            @test isfile(manifest_path)

            # Read it back
            parsed = parse_manifest(manifest_path)
            @test parsed.name == "test_case"
            @test parsed.description == "Test"
            @test length(parsed.files) == 2
        end
    end

    @testset "file_entry" begin
        using PowerfulCases: file_entry, get_default_file, Manifest, FileEntry

        files = [
            FileEntry("v33.raw", :psse_raw; format_version="33", default=true),
            FileEntry("v34.raw", :psse_raw; format_version="34"),
            FileEntry("default.dyr", :psse_dyr; default=true),
            FileEntry("genrou.dyr", :psse_dyr; variant="genrou"),
        ]
        manifest = Manifest("test"; files=files)

        # Get by format only
        entry = file_entry(manifest, :psse_raw)
        @test entry !== nothing
        @test entry.path == "v33.raw"

        # Get by format_version
        entry = file_entry(manifest, :psse_raw; format_version="34")
        @test entry !== nothing
        @test entry.path == "v34.raw"

        # Get by variant
        entry = file_entry(manifest, :psse_dyr; variant="genrou")
        @test entry !== nothing
        @test entry.path == "genrou.dyr"

        # Get default file
        entry = get_default_file(manifest, :psse_raw)
        @test entry !== nothing
        @test entry.default == true

        # Missing format returns nothing
        entry = file_entry(manifest, :matpower)
        @test entry === nothing
    end

    @testset "Legacy API - backward compatibility" begin
        # ieee14() should work but emit deprecation warning
        case = PowerfulCases.ieee14()
        @test case isa PowerfulCases.LegacyCaseBundle
        @test case.name == :ieee14
        @test isfile(case.raw)
        @test case.dyr !== nothing
        @test isdir(case.dir)

        # get_dyr still works
        variants = list_dyr_variants(case)
        @test variants isa Vector{String}

        if !isempty(variants)
            path = get_dyr(case, variants[1])
            @test isfile(path)
            # Functor syntax
            path2 = case(variants[1])
            @test path == path2
        end

        # list_files on legacy bundle
        files = list_files(case)
        @test !isempty(files)
    end

    @testset "Legacy API - get_dyr on CaseBundle" begin
        case = load("ieee14")
        path = get_dyr(case, "genrou")
        @test isfile(path)
        @test occursin("genrou", path)
    end

    @testset "Legacy API - path()" begin
        # Deprecated but should still work
        p = PowerfulCases.path("ieee14.raw")
        @test isfile(p)
    end

    @testset "Cache functions" begin
        using PowerfulCases: get_cache_dir, set_cache_dir, info, is_case_cached, list_cached_cases

        # Default cache dir
        cache_dir = get_cache_dir()
        @test endswith(cache_dir, ".powerfulcases")

        # Cache info
        cache_info = info()
        @test haskey(cache_info, :directory)
        @test haskey(cache_info, :num_cases)
        @test haskey(cache_info, :total_size_mb)

        # Check if case is cached (should be false for most cases)
        @test is_case_cached("nonexistent_case") == false

        # List cached cases
        cached = list_cached_cases()
        @test cached isa Vector{String}
    end

    @testset "Registry functions" begin
        using PowerfulCases: list_remote_cases, is_remote_case, load_registry

        # List remote cases
        remote = list_remote_cases()
        @test remote isa Vector{String}

        # Check if a case is remote
        @test is_remote_case("nonexistent_xyz") == false

        # Load registry
        registry = load_registry()
        @test registry isa PowerfulCases.Registry
    end

    @testset "manifest helper" begin
        using PowerfulCases: manifest

        # Create a temp directory with a .raw file
        mktempdir() do dir
            # Create a test file
            touch(joinpath(dir, "test.raw"))

            # manifest should work
            manifest_path = manifest(dir)
            @test isfile(manifest_path)
            @test endswith(manifest_path, "manifest.toml")
        end
    end

    @testset "manifest with ambiguous files" begin
        using PowerfulCases: manifest

        mktempdir() do dir
            # Create ambiguous .m file
            touch(joinpath(dir, "case.m"))

            # Should still create manifest but with placeholder format
            manifest_path = manifest(dir)
            @test isfile(manifest_path)

            # Read and check it has placeholder
            content = read(manifest_path, String)
            @test occursin("matpower_or_psat", content)
        end
    end

    @testset "Multiple cases" begin
        # Test a few different cases load correctly
        for name in ["ieee14", "ieee39", "case5", "npcc"]
            case = load(name)
            @test case.name == name
            @test isfile(case.raw)
        end
    end

    @testset "Advanced cache tests" begin
        using PowerfulCases: set_cache_dir, ensure_cache_dir, get_cached_case_dir,
                             clear, download_file

        original = get_cache_dir()
        try
            # Test set_cache_dir
            mktempdir() do dir
                new_cache = joinpath(dir, "custom_cache")
                result = set_cache_dir(new_cache)
                @test result == abspath(new_cache)
                @test isdir(new_cache)
                @test get_cache_dir() == abspath(new_cache)
            end

            # Test ensure_cache_dir
            mktempdir() do dir
                new_cache = joinpath(dir, "ensure_test")
                set_cache_dir(new_cache)
                result = ensure_cache_dir()
                @test isdir(result)
            end

            # Test get_cached_case_dir
            set_cache_dir(original)
            @test get_cached_case_dir("test_case") == joinpath(get_cache_dir(), "test_case")

            # Test download_file exists and is callable
            @test isdefined(PowerfulCases, :download_file)

            # Test clear specific case
            mktempdir() do dir
                set_cache_dir(dir)
                test_case = joinpath(dir, "test_case")
                mkpath(test_case)
                write(joinpath(test_case, "manifest.toml"), "name = \"test_case\"")
                @test isdir(test_case)
                clear("test_case")
                @test !isdir(test_case)
            end

            # Test clear all
            mktempdir() do dir
                cache_dir = joinpath(dir, "cache")
                set_cache_dir(cache_dir)
                mkpath(cache_dir)
                mkpath(joinpath(cache_dir, "case1"))
                mkpath(joinpath(cache_dir, "case2"))
                @test isdir(cache_dir)
                clear(nothing)
                @test !isdir(cache_dir)
            end
        finally
            set_cache_dir(original)  # Always restore
        end
    end

    @testset "Advanced registry tests" begin
        using PowerfulCases: parse_registry, Registry, get_case_base_url,
                             bundled_registry_path, cached_registry_path,
                             download

        # Test parse_registry with new format
        mktempdir() do dir
            registry_file = joinpath(dir, "registry.toml")
            write(registry_file, """
version = "1.0.0"
base_url = "https://example.com/cases"
remote_cases = ["case1", "case2", "case3"]
""")
            registry = parse_registry(registry_file)
            @test registry.version == "1.0.0"
            @test registry.base_url == "https://example.com/cases"
            @test "case1" in registry.remote_cases
            @test "case2" in registry.remote_cases
            @test "case3" in registry.remote_cases
            @test length(registry.remote_cases) == 3
        end

        # Test registry has base_url
        registry = load_registry()
        @test hasproperty(registry, :base_url) || hasfield(typeof(registry), :base_url)
        @test registry.base_url isa String

        # Test registry has remote_cases
        @test hasproperty(registry, :remote_cases) || hasfield(typeof(registry), :remote_cases)
        @test registry.remote_cases isa Vector{String}

        # Test get_case_base_url
        if !isempty(registry.remote_cases)
            case_name = registry.remote_cases[1]
            url = get_case_base_url(case_name)
            @test occursin(case_name, url)
            @test occursin(registry.base_url, url)
        end

        # Test bundled_registry_path
        @test endswith(bundled_registry_path(), "registry.toml")

        # Test cached_registry_path
        @test endswith(cached_registry_path(), "registry.toml")

        # Test Registry() default constructor
        empty_registry = Registry()
        @test isempty(empty_registry.remote_cases)
        @test empty_registry.version == "0.0.0"

        # Test download with unknown case
        @test_throws ErrorException download("nonexistent_xyz")

        # Test download with cached case (should return early)
        if !isempty(registry.remote_cases)
            original = get_cache_dir()
            try
                mktempdir() do dir
                    set_cache_dir(dir)
                    case_name = registry.remote_cases[1]
                    test_case = joinpath(dir, case_name)
                    mkpath(test_case)
                    write(joinpath(test_case, "manifest.toml"), "name = \"$case_name\"")
                    result = download(case_name; force=false)
                    @test result == test_case
                end
            finally
                set_cache_dir(original)
            end
        end

        # Test actual download of remote case from GitHub
        # This verifies the remote download works correctly with cuihantao/PowerfulCases repo
        if !isempty(registry.remote_cases)
            original = get_cache_dir()
            try
                mktempdir() do dir
                    set_cache_dir(dir)
                    case_name = registry.remote_cases[1]

                    # Download the remote case
                    result = download(case_name; force=true)
                    case_dir = joinpath(dir, case_name)

                    # Verify download succeeded
                    @test result == case_dir
                    @test isdir(case_dir)
                    @test isfile(joinpath(case_dir, "manifest.toml"))

                    # Parse manifest and verify files were downloaded
                    manifest = parse_manifest(joinpath(case_dir, "manifest.toml"))
                    @test manifest.name == case_name
                    @test !isempty(manifest.files)

                    # Check at least the first file exists
                    first_file = manifest.files[1].path
                    @test isfile(joinpath(case_dir, first_file))
                end
            finally
                set_cache_dir(original)
            end
        end
    end

    @testset "Edge cases" begin
        using PowerfulCases: infer_manifest, formats, variants, Manifest, FileEntry

        # Test empty directory
        mktempdir() do dir
            manifest = infer_manifest(dir)
            @test isempty(manifest.files)
            @test manifest.name == basename(dir)
        end

        # Test multiple files of same format
        mktempdir() do dir
            touch(joinpath(dir, "case1.raw"))
            touch(joinpath(dir, "case2.raw"))
            manifest = infer_manifest(dir)
            @test length(manifest.files) == 2
            # Only first should be default
            defaults = filter(f -> f.default, manifest.files)
            @test length(defaults) == 1
        end

        # Test case-insensitive extensions
        mktempdir() do dir
            touch(joinpath(dir, "case.RAW"))
            touch(joinpath(dir, "case.DYR"))
            manifest = infer_manifest(dir)
            format_list = [f.format for f in manifest.files]
            @test :psse_raw in format_list
            @test :psse_dyr in format_list
        end

        # Test subdirectories are ignored
        mktempdir() do dir
            mkdir(joinpath(dir, "subdir"))
            touch(joinpath(dir, "case.raw"))
            manifest = infer_manifest(dir)
            @test length(manifest.files) == 1
        end

        # Test unknown extensions are ignored
        mktempdir() do dir
            touch(joinpath(dir, "file.xyz"))
            touch(joinpath(dir, "file.raw"))
            manifest = infer_manifest(dir)
            @test length(manifest.files) == 1
            @test manifest.files[1].format == :psse_raw
        end

        # Test formats with duplicates
        files = [
            FileEntry("a.raw", :psse_raw),
            FileEntry("b.raw", :psse_raw),
            FileEntry("c.dyr", :psse_dyr),
        ]
        manifest = Manifest("test"; files=files)
        format_list = formats(manifest)
        @test length(format_list) == 2
        @test :psse_raw in format_list
        @test :psse_dyr in format_list

        # Test variants with no variants
        files = [FileEntry("a.raw", :psse_raw)]
        manifest = Manifest("test"; files=files)
        variant_list = variants(manifest, :psse_raw)
        @test isempty(variant_list)

        # Test variants with default
        files = [
            FileEntry("default.dyr", :psse_dyr; default=true),
            FileEntry("genrou.dyr", :psse_dyr; variant="genrou"),
        ]
        manifest = Manifest("test"; files=files)
        variant_list = variants(manifest, :psse_dyr)
        @test "default" in variant_list
        @test "genrou" in variant_list

        # Test manifest with data_version
        mktempdir() do dir
            files = [FileEntry("test.raw", :psse_raw)]
            manifest = Manifest("test"; description="Test case", data_version="2024.1", files=files)
            path = joinpath(dir, "manifest.toml")
            write_manifest(manifest, path)

            parsed = parse_manifest(path)
            @test parsed.data_version == "2024.1"
        end

        # Test FileEntry with format_version
        mktempdir() do dir
            files = [
                FileEntry("v33.raw", :psse_raw; format_version="33", default=true),
                FileEntry("v34.raw", :psse_raw; format_version="34"),
            ]
            manifest = Manifest("test"; files=files)
            path = joinpath(dir, "manifest.toml")
            write_manifest(manifest, path)

            parsed = parse_manifest(path)
            v33 = filter(f -> f.format_version == "33", parsed.files)
            @test length(v33) == 1
            @test v33[1].default == true
        end

        # Test file_entry with variant="default"
        using PowerfulCases: file_entry
        files = [
            FileEntry("default.dyr", :psse_dyr; default=true),
            FileEntry("genrou.dyr", :psse_dyr; variant="genrou"),
        ]
        manifest = Manifest("test"; files=files)
        entry = file_entry(manifest, :psse_dyr; variant="default")
        @test entry !== nothing
        @test entry.path == "default.dyr"

        # Test load with absolute path
        cases_dir = joinpath(@__DIR__, "..", "powerfulcases", "cases", "ieee14")
        abs_path = abspath(cases_dir)
        case = load(abs_path)
        @test case.name == "ieee14"
    end

    @testset "Manifest paths" begin
        # Test parse_manifest with String (not just joinpath)
        cases_dir = joinpath(@__DIR__, "..", "powerfulcases", "cases", "ieee14")
        manifest_path = string(joinpath(cases_dir, "manifest.toml"))
        manifest = parse_manifest(manifest_path)
        @test manifest.name == "ieee14"
    end

    @testset "Credits API" begin
        using PowerfulCases: Citation, Credits, get_credits, get_license, get_authors,
                             get_maintainers, get_citations, has_credits, write_manifest

        # Test Citation struct
        cit = Citation("Test citation"; doi="10.1234/test")
        @test cit.text == "Test citation"
        @test cit.doi == "10.1234/test"

        cit_no_doi = Citation("No DOI citation"; doi=nothing)
        @test cit_no_doi.doi === nothing

        # Test Credits struct
        credits = Credits(;
            license="CC0-1.0",
            authors=["Author 1", "Author 2"],
            maintainers=["Maintainer 1"],
            citations=[cit]
        )
        @test credits.license == "CC0-1.0"
        @test length(credits.authors) == 2
        @test length(credits.maintainers) == 1
        @test length(credits.citations) == 1

        # Test empty Credits
        empty_credits = Credits()
        @test empty_credits.license === nothing
        @test isempty(empty_credits.authors)
        @test isempty(empty_credits.maintainers)
        @test isempty(empty_credits.citations)

        # Test Manifest with credits
        manifest_with_credits = Manifest("test_case";
            description="Test case with credits",
            credits=credits
        )
        @test manifest_with_credits.credits !== nothing
        @test manifest_with_credits.credits.license == "CC0-1.0"

        # Test Manifest without credits
        manifest_no_credits = Manifest("test_case_no_credits")
        @test manifest_no_credits.credits === nothing

        # Test CaseBundle credits API
        mktempdir() do dir
            # Create a manifest with credits
            manifest_path = joinpath(dir, "manifest.toml")
            manifest = Manifest("test_credits_case";
                description="Test case",
                credits=credits,
                files=[FileEntry("test.raw", :psse_raw; default=true)]
            )
            write_manifest(manifest, manifest_path)

            # Create dummy file
            write(joinpath(dir, "test.raw"), "dummy")

            # Load case and test credits API
            case = load(dir)
            @test has_credits(case)
            @test get_credits(case) !== nothing
            @test get_license(case) == "CC0-1.0"
            @test get_authors(case) == ["Author 1", "Author 2"]
            @test get_maintainers(case) == ["Maintainer 1"]
            @test length(get_citations(case)) == 1
            @test get_citations(case)[1].text == "Test citation"
            @test get_citations(case)[1].doi == "10.1234/test"
        end

        # Test case without credits (create a temp case)
        mktempdir() do dir
            # Create a manifest without credits
            manifest = Manifest("no_credits_case";
                description="Test case without credits",
                files=[FileEntry("test.raw", :psse_raw; default=true)]
            )
            write_manifest(manifest, joinpath(dir, "manifest.toml"))
            write(joinpath(dir, "test.raw"), "dummy")

            case_no_credits = load(dir)
            @test !has_credits(case_no_credits)
            @test get_credits(case_no_credits) === nothing
            @test get_license(case_no_credits) === nothing
            @test isempty(get_authors(case_no_credits))
            @test isempty(get_maintainers(case_no_credits))
            @test isempty(get_citations(case_no_credits))
        end

        # Test parse_manifest with credits
        mktempdir() do dir
            manifest_toml = """
            name = "credits_test"
            description = "Test manifest with credits"

            [credits]
            license = "MIT"
            authors = ["John Doe", "Jane Smith"]
            maintainers = ["Maintainer A"]

            [[credits.citations]]
            text = "Doe, J. (2024). Test Paper."
            doi = "10.5555/12345"

            [[credits.citations]]
            text = "Smith, J. (2023). Another Paper."

            [[files]]
            path = "test.raw"
            format = "psse_raw"
            default = true
            """
            manifest_path = joinpath(dir, "manifest.toml")
            write(manifest_path, manifest_toml)

            manifest = parse_manifest(manifest_path)
            @test manifest.credits !== nothing
            @test manifest.credits.license == "MIT"
            @test manifest.credits.authors == ["John Doe", "Jane Smith"]
            @test manifest.credits.maintainers == ["Maintainer A"]
            @test length(manifest.credits.citations) == 2
            @test manifest.credits.citations[1].text == "Doe, J. (2024). Test Paper."
            @test manifest.credits.citations[1].doi == "10.5555/12345"
            @test manifest.credits.citations[2].text == "Smith, J. (2023). Another Paper."
            @test manifest.credits.citations[2].doi === nothing
        end

        # Test write_manifest with credits
        mktempdir() do dir
            manifest = Manifest("write_test";
                credits=Credits(;
                    license="Apache-2.0",
                    authors=["Test Author"],
                    maintainers=["Test Maintainer"],
                    citations=[Citation("Test citation"; doi="10.1234/write")]
                )
            )
            manifest_path = joinpath(dir, "manifest.toml")
            write_manifest(manifest, manifest_path)

            # Read it back
            parsed = parse_manifest(manifest_path)
            @test parsed.credits !== nothing
            @test parsed.credits.license == "Apache-2.0"
            @test parsed.credits.authors == ["Test Author"]
            @test parsed.credits.maintainers == ["Test Maintainer"]
            @test length(parsed.credits.citations) == 1
            @test parsed.credits.citations[1].doi == "10.1234/write"
        end
    end
end
