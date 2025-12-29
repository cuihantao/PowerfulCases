# Test collection organization functionality for PowerfulCases.

using Test
using PowerfulCases

@testset "Collections" begin
    @testset "collections() function" begin
        @test collections() isa Vector{String}
        @test length(collections()) > 0

        # Check expected collections exist
        colls = collections()
        @test "ieee-transmission" in colls
        @test "synthetic" in colls
        @test "matpower" in colls
        @test "test" in colls

        # Check sorted
        @test colls == sort(colls)
    end

    @testset "cases() filtering" begin
        # No filter returns all cases
        all_cases = cases()
        @test all_cases isa Vector{String}
        @test length(all_cases) == 88

        # Filter by collection
        trans_cases = cases(collection="ieee-transmission")
        @test length(trans_cases) == 8
        @test "ieee14" in trans_cases
        @test "ieee39" in trans_cases
        @test "ieee118" in trans_cases

        # Synthetic collection
        synth_cases = cases(collection="synthetic")
        @test length(synth_cases) == 10
        @test "ACTIVSg2000" in synth_cases

        # Nonexistent collection returns empty
        @test cases(collection="nonexistent") == []

        # Cases are sorted
        @test all_cases == sort(all_cases)
    end

    @testset "load() searches collections" begin
        # Load by name (searches collections)
        case = load("ieee14")
        @test case.name == "ieee14"
        @test case.collection == "ieee-transmission"

        # Load with collection/case path
        case2 = load("ieee-transmission/ieee14")
        @test case2.name == "ieee14"
        @test case2.collection == "ieee-transmission"

        # Unknown case raises error
        @test_throws ErrorException load("nonexistent_case_xyz")
    end

    @testset "CaseBundle properties" begin
        case = load("ieee14")

        # Collection property
        @test case.collection == "ieee-transmission"

        # Tags property
        @test case.tags isa Vector{String}
        # Tags are empty until we add them to manifests

        # Collection inferred from directory
        case2 = load("ieee118")
        @test case2.collection == "ieee-transmission"
    end

    @testset "Backward compatibility" begin
        # Load by name still works
        case = load("ieee14")
        @test case.name == "ieee14"

        # cases() returns all cases
        all_cases = cases()
        @test length(all_cases) == 88
        @test "ieee14" in all_cases
        @test "ACTIVSg2000" in all_cases
        @test "case118zh" in all_cases
    end
end
