"""
Test collection organization functionality.
"""
import pytest
from powerfulcases import load, cases, collections


class TestCollections:
    """Test collection listing and organization."""

    def test_collections_returns_list(self):
        """collections() returns a list of collection names."""
        colls = collections()
        assert isinstance(colls, list)
        assert len(colls) > 0

    def test_collections_includes_expected(self):
        """collections() includes expected collection names."""
        colls = collections()
        expected = ['ieee-transmission', 'ieee-distribution', 'synthetic', 'matpower', 'test']
        for coll in expected:
            assert coll in colls, f"Expected collection '{coll}' not found"

    def test_collections_sorted(self):
        """collections() returns sorted list."""
        colls = collections()
        assert colls == sorted(colls)


class TestCasesFiltering:
    """Test cases() function with filtering."""

    def test_cases_no_filter_returns_all(self):
        """cases() without filter returns all cases."""
        all_cases = cases()
        assert isinstance(all_cases, list)
        assert len(all_cases) == 88  # Total expected cases

    def test_cases_filter_by_collection(self):
        """cases(collection=...) filters correctly."""
        trans_cases = cases(collection='ieee-transmission')
        assert len(trans_cases) == 8
        expected = ['ieee14', 'ieee30', 'ieee39', 'ieee57', 'ieee118', 'ieee300', 'ieee24_rts', 'npcc']
        for case in expected:
            assert case in trans_cases

    def test_cases_filter_ieee_distribution(self):
        """IEEE distribution collection (currently empty, cases not yet moved)."""
        dist_cases = cases(collection='ieee-distribution')
        # NOTE: OpenDSS cases are still in flat structure, not moved to collection yet
        assert isinstance(dist_cases, list)

    def test_cases_filter_synthetic(self):
        """Synthetic collection has expected cases."""
        synth_cases = cases(collection='synthetic')
        assert len(synth_cases) == 10
        assert 'ACTIVSg2000' in synth_cases

    def test_cases_filter_nonexistent_collection(self):
        """Filtering by nonexistent collection returns empty list."""
        result = cases(collection='nonexistent')
        assert result == []

    def test_cases_sorted(self):
        """cases() returns sorted list."""
        all_cases = cases()
        assert all_cases == sorted(all_cases)


class TestLoadByName:
    """Test loading cases by name (searches collections)."""

    def test_load_searches_collections(self):
        """load() finds cases in collections without specifying collection."""
        case = load('ieee14')
        assert case.name == 'ieee14'
        assert case.collection == 'ieee-transmission'

    def test_load_with_collection_path(self):
        """load('collection/case') works."""
        case = load('ieee-transmission/ieee14')
        assert case.name == 'ieee14'
        assert case.collection == 'ieee-transmission'

    def test_load_unknown_case_raises(self):
        """load() raises ValueError for unknown case."""
        with pytest.raises(ValueError, match="Unknown case"):
            load('nonexistent_case_xyz')


class TestCaseBundleProperties:
    """Test CaseBundle collection and tags properties."""

    def test_collection_property(self):
        """CaseBundle.collection returns collection name."""
        case = load('ieee14')
        assert case.collection == 'ieee-transmission'

    def test_tags_property(self):
        """CaseBundle.tags returns list (empty if not defined)."""
        case = load('ieee14')
        assert isinstance(case.tags, list)
        # Tags are empty until we add them to manifests

    def test_collection_inferred_from_directory(self):
        """Collection is inferred from directory structure."""
        case = load('ieee118')
        assert case.collection == 'ieee-transmission'


class TestBackwardCompatibility:
    """Test that existing functionality still works."""

    def test_load_by_name_still_works(self):
        """Legacy flat name loading still works."""
        case = load('ieee14')
        assert case.name == 'ieee14'

    def test_cases_returns_all_cases(self):
        """cases() returns all 88 cases."""
        all_cases = cases()
        assert len(all_cases) == 88
        assert 'ieee14' in all_cases
        assert 'ACTIVSg2000' in all_cases
        assert 'case118zh' in all_cases
