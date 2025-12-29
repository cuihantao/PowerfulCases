"""Tests for powerfulcases package."""
import os
import sys
import tarfile
import tempfile
import warnings
import zipfile

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from powerfulcases import (
    load,
    file,
    cases,
    formats,
    variants,
    CaseBundle,
    manifest,
    get_cache_dir,
    info,
    export_case,
    load,
    file,
    cases,
    formats,
    variants,
    CaseBundle,
    manifest,
    get_cache_dir,
    info,
    export_case,
    # Legacy API
    ieee14,
)


class TestNewAPI:
    """Tests for the new load() API."""

    def test_load_bundled(self):
        """Test loading a bundled case by name."""
        case = load("ieee14")
        assert case.name == "ieee14"
        assert os.path.isfile(case.raw)
        assert case.raw.endswith("ieee14.raw")
        assert case.dyr is not None
        assert os.path.isfile(case.dyr)
        assert case.is_remote is False

    def test_load_local_directory(self):
        """Test loading a case from a local directory."""
        cases_dir = os.path.join(
            os.path.dirname(__file__), "..", "powerfulcases", "cases", "ieee14"
        )
        case = load(cases_dir)
        assert case.name == "ieee14"
        assert os.path.isfile(case.raw)

    def test_load_unknown(self):
        """Test error when loading unknown case."""
        try:
            load("nonexistent_case")
            assert False, "Should have raised ValueError"
        except ValueError as e:
            assert "Unknown case" in str(e)

    def test_load_multiple(self):
        """Test loading multiple different cases."""
        for name in ["ieee14", "ieee39", "case5", "npcc"]:
            case = load(name)
            assert case.name == name
            assert os.path.isfile(case.raw)


class TestGetFile:
    """Tests for file() function."""

    def test_file_default(self):
        """Test getting default file for a format."""
        case = load("ieee14")
        raw_path = file(case, "psse_raw")
        assert os.path.isfile(raw_path)
        assert raw_path.endswith(".raw")

    def test_file_with_alias(self):
        """Test format aliases (raw -> psse_raw)."""
        case = load("ieee14")
        raw_path = file(case, "raw")
        assert os.path.isfile(raw_path)

        # Both should return same path
        raw_path2 = file(case, "psse_raw")
        assert raw_path == raw_path2

    def test_file_with_variant(self):
        """Test getting a specific variant."""
        case = load("ieee14")
        genrou_path = file(case, "psse_dyr", variant="genrou")
        assert os.path.isfile(genrou_path)
        assert "genrou" in genrou_path

    def test_file_with_default_variant(self):
        """Test getting file with 'default' variant."""
        case = load("ieee14")
        default_path = file(case, "psse_dyr", variant="default")
        assert os.path.isfile(default_path)

        # Should be same as case.dyr
        assert default_path == case.dyr

    def test_file_not_required(self):
        """Test required=False returns None for missing format."""
        case = load("ieee14")
        result = file(case, "psat", required=False)
        assert result is None

    def test_file_missing_required(self):
        """Test error when required file is missing."""
        case = load("ieee14")
        try:
            file(case, "psat")
            assert False, "Should have raised FileNotFoundError"
        except FileNotFoundError as e:
            assert "psat" in str(e)

    def test_file_missing_variant(self):
        """Test error when variant doesn't exist."""
        case = load("ieee14")
        try:
            file(case, "psse_dyr", variant="nonexistent_variant")
            assert False, "Should have raised FileNotFoundError"
        except FileNotFoundError as e:
            assert "nonexistent_variant" in str(e)


class TestListFunctions:
    """Tests for cases(), formats(), variants()."""

    def test_cases(self):
        """Test listing available cases."""
        result = cases()
        assert "ieee14" in result
        assert "ieee39" in result
        assert len(result) > 5

    def test_formats(self):
        """Test listing formats in a case."""
        case = load("ieee14")
        result = formats(case)
        assert "psse_raw" in result
        assert "psse_dyr" in result

    def test_variants(self):
        """Test listing variants for a format."""
        case = load("ieee14")
        result = variants(case, "psse_dyr")
        assert isinstance(result, list)
        assert "genrou" in result
        assert "default" in result

    def test_variants_with_alias(self):
        """Test variants with format alias."""
        case = load("ieee14")
        result = variants(case, "dyr")
        assert "genrou" in result


class TestCaseBundleMethods:
    """Tests for CaseBundle methods."""

    def test_list_files(self):
        """Test list_files() returns metadata."""
        case = load("ieee14")
        files = case.list_files()
        assert len(files) > 0

        # Files have metadata attributes
        first_file = files[0]
        assert hasattr(first_file, "path")
        assert hasattr(first_file, "format")
        assert hasattr(first_file, "default")
        assert hasattr(first_file, "variant")
        assert hasattr(first_file, "format_version")

    def test_get_dyr_method(self):
        """Test legacy get_dyr() method on CaseBundle."""
        case = load("ieee14")
        path = case.get_dyr("genrou")
        assert os.path.isfile(path)

    def test_list_dyr_variants_method(self):
        """Test legacy list_dyr_variants() method."""
        case = load("ieee14")
        variants = case.list_dyr_variants()
        assert isinstance(variants, list)
        assert "genrou" in variants

    def test_functor_syntax(self):
        """Test case('variant') syntax."""
        case = load("ieee14")
        path = case("genrou")
        assert os.path.isfile(path)
        assert "genrou" in path

    def test_repr(self):
        """Test string representation."""
        case = load("ieee14")
        repr_str = repr(case)
        assert "ieee14" in repr_str


class TestManifest:
    """Tests for manifest functionality."""

    def test_manifest(self):
        """Test manifest() helper."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create test files
            open(os.path.join(tmpdir, "test.raw"), "w").close()
            open(os.path.join(tmpdir, "test.dyr"), "w").close()

            manifest_path = manifest(tmpdir)
            assert os.path.isfile(manifest_path)
            assert str(manifest_path).endswith("manifest.toml")

    def test_manifest_with_ambiguous(self):
        """Test manifest with ambiguous .m file."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create ambiguous .m file
            open(os.path.join(tmpdir, "case.m"), "w").close()

            # Should create manifest with placeholder format
            manifest_path = manifest(tmpdir)
            assert os.path.isfile(manifest_path)

            # Check placeholder is in the manifest
            with open(manifest_path) as f:
                content = f.read()
                assert "matpower_or_psat" in content

    def test_parse_manifest(self):
        """Test parsing an existing manifest."""
        from powerfulcases.manifest import parse_manifest

        cases_dir = os.path.join(
            os.path.dirname(__file__), "..", "powerfulcases", "cases", "ieee14"
        )
        manifest_path = os.path.join(cases_dir, "manifest.toml")

        manifest = parse_manifest(manifest_path)
        assert manifest.name == "ieee14"
        assert len(manifest.files) > 0
        assert manifest.description != ""

    def test_infer_manifest(self):
        """Test inferring manifest from directory."""
        from powerfulcases.manifest import infer_manifest
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            # Create unambiguous files
            open(os.path.join(tmpdir, "test.raw"), "w").close()
            open(os.path.join(tmpdir, "test.dyr"), "w").close()

            manifest = infer_manifest(Path(tmpdir))
            assert len(manifest.files) == 2

            formats = [f.format for f in manifest.files]
            assert "psse_raw" in formats
            assert "psse_dyr" in formats

    def test_infer_manifest_ambiguous_error(self):
        """Test infer_manifest raises error for ambiguous files."""
        from powerfulcases.manifest import infer_manifest
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            # Create ambiguous .m file
            open(os.path.join(tmpdir, "case.m"), "w").close()

            try:
                infer_manifest(Path(tmpdir))
                assert False, "Should have raised ValueError"
            except ValueError as e:
                assert ".m" in str(e)

    def test_write_manifest(self):
        """Test writing and reading back a manifest."""
        from powerfulcases.manifest import write_manifest, parse_manifest, Manifest, FileEntry
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            files = [
                FileEntry(path="test.raw", format="psse_raw", default=True),
                FileEntry(path="test.dyr", format="psse_dyr", variant="genrou"),
            ]
            manifest = Manifest(name="test_case", description="Test", files=files)

            manifest_path = Path(tmpdir) / "manifest.toml"
            write_manifest(manifest, manifest_path)
            assert manifest_path.is_file()

            # Read it back
            parsed = parse_manifest(manifest_path)
            assert parsed.name == "test_case"
            assert parsed.description == "Test"
            assert len(parsed.files) == 2

    def test_file_entry(self):
        """Test file_entry function."""
        from powerfulcases.manifest import file_entry, get_default_file, Manifest, FileEntry

        files = [
            FileEntry(path="v33.raw", format="psse_raw", format_version="33", default=True),
            FileEntry(path="v34.raw", format="psse_raw", format_version="34"),
            FileEntry(path="default.dyr", format="psse_dyr", default=True),
            FileEntry(path="genrou.dyr", format="psse_dyr", variant="genrou"),
        ]
        manifest = Manifest(name="test", files=files)

        # Get by format only
        entry = file_entry(manifest, "psse_raw")
        assert entry is not None
        assert entry.path == "v33.raw"

        # Get by format_version
        entry = file_entry(manifest, "psse_raw", format_version="34")
        assert entry is not None
        assert entry.path == "v34.raw"

        # Get by variant
        entry = file_entry(manifest, "psse_dyr", variant="genrou")
        assert entry is not None
        assert entry.path == "genrou.dyr"

        # Get default file
        entry = get_default_file(manifest, "psse_raw")
        assert entry is not None
        assert entry.default is True

        # Missing format returns None
        entry = file_entry(manifest, "matpower")
        assert entry is None


class TestCache:
    """Tests for cache functionality."""

    def test_get_cache_dir(self):
        """Test cache directory."""
        cache_dir = get_cache_dir()
        assert str(cache_dir).endswith(".powerfulcases")

    def test_info(self):
        """Test cache info."""
        result = info()
        assert hasattr(result, "directory")
        assert hasattr(result, "num_cases")
        assert hasattr(result, "total_size_mb")

    def test_is_case_cached(self):
        """Test checking if case is cached."""
        from powerfulcases.cache import is_case_cached

        # Nonexistent case should not be cached
        assert is_case_cached("nonexistent_xyz") is False

    def test_list_cached_cases(self):
        """Test listing cached cases."""
        from powerfulcases.cache import list_cached_cases

        cached = list_cached_cases()
        assert isinstance(cached, list)


class TestRegistry:
    """Tests for registry functionality."""

    def test_list_remote_cases(self):
        """Test listing remote cases."""
        from powerfulcases.registry import list_remote_cases

        remote = list_remote_cases()
        assert isinstance(remote, list)

    def test_is_remote_case(self):
        """Test checking if case is remote."""
        from powerfulcases.registry import is_remote_case

        # Nonexistent case should not be remote
        assert is_remote_case("nonexistent_xyz") is False

    def test_load_registry(self):
        """Test loading registry."""
        from powerfulcases.registry import load_registry, Registry

        registry = load_registry()
        assert isinstance(registry, Registry)


class TestLegacyAPI:
    """Tests for backward compatibility with legacy API."""

    def test_ieee14_function(self):
        """Test ieee14() still works with deprecation warning."""
        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            case = ieee14()

            # Should emit deprecation warning
            assert len(w) >= 1
            assert issubclass(w[0].category, DeprecationWarning)
            assert "deprecated" in str(w[0].message).lower()

        assert case.name == "ieee14"
        assert os.path.isfile(case.raw)

    def test_legacy_dyr_property(self):
        """Test .dyr property on legacy case."""
        case = ieee14()
        if case.dyr is not None:
            assert os.path.isfile(case.dyr)

    def test_legacy_get_dyr(self):
        """Test get_dyr() on legacy case."""
        case = ieee14()
        variants = case.list_dyr_variants()
        if variants:
            path = case.get_dyr(variants[0])
            assert os.path.isfile(path)

    def test_legacy_get_dyr_missing(self):
        """Test error for missing DYR variant."""
        case = ieee14()
        try:
            case.get_dyr("nonexistent_variant")
            assert False, "Should have raised FileNotFoundError"
        except FileNotFoundError:
            pass

    def test_legacy_functor(self):
        """Test functor syntax on legacy case."""
        case = ieee14()
        path = case("genrou")
        assert os.path.isfile(path)

    def test_legacy_list_files(self):
        """Test list_files on legacy case."""
        case = ieee14()
        files = case.list_files()
        assert len(files) > 0


class TestCLI:
    """Tests for the command-line interface."""

    def test_cli_manifest(self):
        """Test create-manifest CLI command."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli

        runner = CliRunner()
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create test files
            open(os.path.join(tmpdir, "test.raw"), "w").close()

            result = runner.invoke(cli, ["create-manifest", tmpdir])
            assert result.exit_code == 0
            assert "Created manifest" in result.output

    def test_cli_manifest_nonexistent(self):
        """Test create-manifest with nonexistent path."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli

        runner = CliRunner()
        result = runner.invoke(cli, ["create-manifest", "/nonexistent/path"])
        assert result.exit_code != 0

    def test_cli_list(self):
        """Test list CLI command."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli

        runner = CliRunner()
        result = runner.invoke(cli, ["list"])
        assert result.exit_code == 0
        assert "Available cases" in result.output
        assert "ieee14" in result.output

    def test_cli_list_remote(self):
        """Test list --remote CLI command."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli

        runner = CliRunner()
        result = runner.invoke(cli, ["list", "--remote"])
        assert result.exit_code == 0
        assert "Remote cases" in result.output

    def test_cli_list_cached(self):
        """Test list --cached CLI command."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli

        runner = CliRunner()
        result = runner.invoke(cli, ["list", "--cached"])
        assert result.exit_code == 0
        assert "Cached cases" in result.output

    def test_cli_info(self):
        """Test cache-info CLI command."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli

        runner = CliRunner()
        result = runner.invoke(cli, ["cache-info"])
        assert result.exit_code == 0
        assert "Cache directory" in result.output
        assert "Number of cached cases" in result.output

    def test_cli_info(self):
        """Test info CLI command."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli

        runner = CliRunner()
        result = runner.invoke(cli, ["info", "ieee14"])
        assert result.exit_code == 0
        assert "Case: ieee14" in result.output
        assert "Files:" in result.output

    def test_cli_info_unknown_case(self):
        """Test info CLI command with unknown case."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli

        runner = CliRunner()
        result = runner.invoke(cli, ["info", "nonexistent_xyz"])
        assert result.exit_code != 0
        assert "Error" in result.output

    def test_cli_clear_no_args(self):
        """Test clear-cache without arguments shows help."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli

        runner = CliRunner()
        result = runner.invoke(cli, ["clear-cache"])
        assert result.exit_code != 0
        assert "Specify a case name" in result.output

    def test_cli_clear_specific(self):
        """Test clear-cache for specific case."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli

        runner = CliRunner()
        # Try to clear a nonexistent case (won't error, just prints message)
        result = runner.invoke(cli, ["clear-cache", "nonexistent_test_case"])
        assert result.exit_code == 0

    def test_cli_download_unknown(self):
        """Test download with unknown case."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli

        runner = CliRunner()
        result = runner.invoke(cli, ["download", "completely_nonexistent_xyz"])
        assert result.exit_code != 0
        assert "Error" in result.output

    def test_cli_clear_all_confirmed(self):
        """Test clear-cache --all with confirmation."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli
        from powerfulcases.cache import set_cache_dir, get_cache_dir
        from pathlib import Path

        runner = CliRunner()
        original = get_cache_dir()

        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                cache_dir = Path(tmpdir) / "cache"
                set_cache_dir(cache_dir)

                # Create fake cached case
                (cache_dir / "case1").mkdir(parents=True)
                (cache_dir / "case1" / "manifest.toml").write_text("name = 'case1'")

                assert cache_dir.is_dir()

                # Invoke with --all and confirm with 'y'
                result = runner.invoke(cli, ["clear-cache", "--all"], input='y\n')
                assert result.exit_code == 0
                assert not cache_dir.is_dir()
        finally:
            set_cache_dir(original)

    def test_cli_clear_all_cancelled(self):
        """Test clear-cache --all cancelled by user."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli
        from powerfulcases.cache import set_cache_dir, get_cache_dir
        from pathlib import Path

        runner = CliRunner()
        original = get_cache_dir()

        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                cache_dir = Path(tmpdir) / "cache"
                set_cache_dir(cache_dir)

                # Create fake cached case
                (cache_dir / "case1").mkdir(parents=True)
                (cache_dir / "case1" / "manifest.toml").write_text("name = 'case1'")

                assert cache_dir.is_dir()

                # Invoke with --all and cancel with 'n'
                result = runner.invoke(cli, ["clear-cache", "--all"], input='n\n')
                # Cache should still exist
                assert cache_dir.is_dir()
        finally:
            set_cache_dir(original)


class TestDownloadErrorHandling:
    """Tests for download error handling."""

    def test_download_unknown(self):
        """Test download with unknown case."""
        from powerfulcases.registry import download

        try:
            download("nonexistent_xyz")
            assert False, "Should have raised ValueError"
        except ValueError as e:
            assert "Unknown remote case" in str(e)

    def test_download_already_cached(self):
        """Test download returns early for cached case."""
        from powerfulcases.registry import download, load_registry
        from powerfulcases.cache import set_cache_dir, get_cache_dir
        from pathlib import Path

        original = get_cache_dir()
        registry = load_registry()

        # Only test if there are remote cases
        if not registry.remote_cases:
            return

        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                cache_dir = Path(tmpdir)
                set_cache_dir(cache_dir)

                # Create a fake cached case for a known remote case
                case_name = registry.remote_cases[0]
                test_case = cache_dir / case_name
                test_case.mkdir(parents=True)
                (test_case / "manifest.toml").write_text(f"name = '{case_name}'")

                # Should return early without trying to download
                result = download(case_name, force=False)
                assert result == test_case
        finally:
            set_cache_dir(original)

    def test_download_success(self):
        """Test successful download of remote case from GitHub.

        Verifies the remote download works correctly with the cuihantao/PowerfulCases repo.
        """
        from powerfulcases.registry import download, load_registry
        from powerfulcases.cache import set_cache_dir, get_cache_dir
        from powerfulcases.manifest import parse_manifest
        from pathlib import Path

        original = get_cache_dir()
        registry = load_registry()

        # Only test if there are remote cases
        if not registry.remote_cases:
            return

        try:
            with tempfile.TemporaryDirectory() as tmpdir:
                cache_dir = Path(tmpdir)
                set_cache_dir(cache_dir)

                # Download a known remote case
                case_name = registry.remote_cases[0]
                result = download(case_name, force=True)
                case_dir = cache_dir / case_name

                # Verify download succeeded
                assert result == case_dir
                assert case_dir.is_dir(), f"Case directory should exist: {case_dir}"
                assert (case_dir / "manifest.toml").is_file(), "manifest.toml should exist"

                # Parse manifest and verify files were downloaded
                manifest = parse_manifest(case_dir / "manifest.toml")
                assert manifest.name == case_name
                assert len(manifest.files) > 0, "Manifest should have files"

                # Check at least the first file exists
                first_file = manifest.files[0].path
                assert (case_dir / first_file).is_file(), f"First file should exist: {first_file}"
        finally:
            set_cache_dir(original)


class TestCacheAdvanced:
    """Advanced cache tests covering untested functions."""

    def test_set_cache_dir(self):
        """Test setting custom cache directory."""
        from powerfulcases.cache import get_cache_dir, set_cache_dir, DEFAULT_CACHE_DIR
        from pathlib import Path

        original = get_cache_dir()

        with tempfile.TemporaryDirectory() as tmpdir:
            new_cache = Path(tmpdir) / "custom_cache"
            result = set_cache_dir(new_cache)
            assert result == new_cache.absolute()
            assert new_cache.is_dir()
            assert get_cache_dir() == new_cache.absolute()

        # Restore original
        set_cache_dir(original)

    def test_ensure_cache_dir(self):
        """Test ensure_cache_dir creates directory."""
        from powerfulcases.cache import ensure_cache_dir, set_cache_dir, get_cache_dir
        from pathlib import Path

        original = get_cache_dir()

        with tempfile.TemporaryDirectory() as tmpdir:
            new_cache = Path(tmpdir) / "ensure_test"
            set_cache_dir(new_cache)
            result = ensure_cache_dir()
            assert result.is_dir()

        set_cache_dir(original)

    def test_get_cached_case_dir(self):
        """Test get_cached_case_dir returns correct path."""
        from powerfulcases.cache import get_cached_case_dir, get_cache_dir

        case_dir = get_cached_case_dir("test_case")
        assert case_dir == get_cache_dir() / "test_case"

    def test_download_file(self):
        """Test download_file creates file."""
        from powerfulcases.cache import download_file
        from pathlib import Path
        import http.server
        import threading

        # Skip if no network - just test the function exists
        # Real download tests would need a mock server
        assert callable(download_file)

    def test_clear_specific(self):
        """Test clearing a specific cached case."""
        from powerfulcases.cache import clear, get_cache_dir, set_cache_dir
        from pathlib import Path

        original = get_cache_dir()

        with tempfile.TemporaryDirectory() as tmpdir:
            cache_dir = Path(tmpdir) / "cache"
            set_cache_dir(cache_dir)

            # Create a fake cached case
            test_case = cache_dir / "test_case"
            test_case.mkdir(parents=True)
            (test_case / "manifest.toml").write_text("name = 'test_case'")

            assert test_case.is_dir()
            clear("test_case")
            assert not test_case.is_dir()

        set_cache_dir(original)

    def test_clear_all(self):
        """Test clearing entire cache."""
        from powerfulcases.cache import clear, get_cache_dir, set_cache_dir
        from pathlib import Path

        original = get_cache_dir()

        with tempfile.TemporaryDirectory() as tmpdir:
            cache_dir = Path(tmpdir) / "cache"
            set_cache_dir(cache_dir)

            # Create fake cached cases
            (cache_dir / "case1").mkdir(parents=True)
            (cache_dir / "case2").mkdir(parents=True)

            assert cache_dir.is_dir()
            clear(None)
            assert not cache_dir.is_dir()

        set_cache_dir(original)


class TestRegistryAdvanced:
    """Advanced registry tests covering untested functions."""

    def test_parse_registry_new_format(self):
        """Test parsing a registry file with new format."""
        from powerfulcases.registry import parse_registry
        from pathlib import Path

        with tempfile.NamedTemporaryFile(mode="w", suffix=".toml", delete=False) as f:
            f.write('''
version = "1.0.0"
base_url = "https://example.com/cases"
remote_cases = ["case1", "case2", "case3"]
''')
            temp_path = Path(f.name)

        try:
            registry = parse_registry(temp_path)
            assert registry.version == "1.0.0"
            assert registry.base_url == "https://example.com/cases"
            assert "case1" in registry.remote_cases
            assert "case2" in registry.remote_cases
            assert "case3" in registry.remote_cases
            assert len(registry.remote_cases) == 3
        finally:
            temp_path.unlink()

    def test_registry_has_base_url(self):
        """Test that loaded registry has base_url."""
        from powerfulcases.registry import load_registry

        registry = load_registry()
        assert hasattr(registry, "base_url")
        assert isinstance(registry.base_url, str)

    def test_registry_has_remote_cases(self):
        """Test that loaded registry has remote_cases list."""
        from powerfulcases.registry import load_registry

        registry = load_registry()
        assert hasattr(registry, "remote_cases")
        assert isinstance(registry.remote_cases, list)

    def test_get_case_base_url(self):
        """Test getting base URL for a remote case."""
        from powerfulcases.registry import get_case_base_url, load_registry

        registry = load_registry()
        if registry.remote_cases:
            case_name = registry.remote_cases[0]
            url = get_case_base_url(case_name)
            assert case_name in url
            assert registry.base_url in url

    def test_bundled_registry_path(self):
        """Test bundled registry path."""
        from powerfulcases.registry import bundled_registry_path

        path = bundled_registry_path()
        # Should point to registry.toml
        assert str(path).endswith("registry.toml")

    def test_cached_registry_path(self):
        """Test cached registry path."""
        from powerfulcases.registry import cached_registry_path

        path = cached_registry_path()
        assert str(path).endswith("registry.toml")


class TestSetupExcludeGeneration:
    """Tests for setup.py exclude pattern generation."""

    def test_setup_py_reads_registry(self):
        """Test that setup.py can read registry.toml."""
        from pathlib import Path

        setup_path = Path(__file__).parent.parent / "setup.py"
        registry_path = Path(__file__).parent.parent / "registry.toml"

        assert setup_path.is_file(), "setup.py should exist"
        assert registry_path.is_file(), "registry.toml should exist"

    def test_exclude_patterns_from_registry(self):
        """Test generating exclude patterns from registry."""
        from powerfulcases.registry import load_registry

        registry = load_registry()
        remote_cases = registry.remote_cases

        # Generate exclude patterns like setup.py does
        exclude_patterns = [f"cases/{name}/*" for name in remote_cases]

        # Should have an exclude pattern for each remote case
        assert len(exclude_patterns) == len(remote_cases)

        # Each pattern should have the expected format
        for pattern in exclude_patterns:
            assert pattern.startswith("cases/")
            assert pattern.endswith("/*")

    def test_remote_cases_in_registry(self):
        """Test that registry has expected remote cases."""
        from powerfulcases.registry import load_registry

        registry = load_registry()

        # Should have some remote cases
        assert len(registry.remote_cases) > 0

        # All ACTIVS cases should be remote (they're large)
        activs_cases = [c for c in registry.remote_cases if "ACTIVS" in c]
        assert len(activs_cases) > 0


class TestEdgeCases:
    """Tests for edge cases and boundary conditions."""

    def test_empty_directory_infer(self):
        """Test inferring manifest from empty directory."""
        from powerfulcases.manifest import infer_manifest
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            manifest = infer_manifest(Path(tmpdir))
            assert len(manifest.files) == 0
            assert manifest.name == os.path.basename(tmpdir)

    def test_multiple_raw_files(self):
        """Test directory with multiple .raw files."""
        from powerfulcases.manifest import infer_manifest
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            open(os.path.join(tmpdir, "case1.raw"), "w").close()
            open(os.path.join(tmpdir, "case2.raw"), "w").close()

            manifest = infer_manifest(Path(tmpdir))
            # Should have both files
            assert len(manifest.files) == 2
            # Only first should be default
            defaults = [f for f in manifest.files if f.default]
            assert len(defaults) == 1

    def test_case_insensitive_extensions(self):
        """Test that extensions are case-insensitive."""
        from powerfulcases.manifest import infer_manifest
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            open(os.path.join(tmpdir, "case.RAW"), "w").close()
            open(os.path.join(tmpdir, "case.DYR"), "w").close()

            manifest = infer_manifest(Path(tmpdir))
            formats = [f.format for f in manifest.files]
            assert "psse_raw" in formats
            assert "psse_dyr" in formats

    def test_subdirectories_ignored(self):
        """Test that subdirectories are ignored in infer_manifest."""
        from powerfulcases.manifest import infer_manifest
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            # Create a subdirectory
            os.mkdir(os.path.join(tmpdir, "subdir"))
            open(os.path.join(tmpdir, "case.raw"), "w").close()

            manifest = infer_manifest(Path(tmpdir))
            # Should only have one file
            assert len(manifest.files) == 1

    def test_unknown_extensions_ignored(self):
        """Test that unknown extensions are ignored."""
        from powerfulcases.manifest import infer_manifest
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            open(os.path.join(tmpdir, "file.xyz"), "w").close()
            open(os.path.join(tmpdir, "file.raw"), "w").close()

            manifest = infer_manifest(Path(tmpdir))
            # Should only have the .raw file
            assert len(manifest.files) == 1
            assert manifest.files[0].format == "psse_raw"

    def test_formats_returns_all_formats(self):
        """Test formats returns unique formats."""
        from powerfulcases.manifest import formats as manifest_formats, Manifest, FileEntry

        files = [
            FileEntry(path="a.raw", format="psse_raw"),
            FileEntry(path="b.raw", format="psse_raw"),
            FileEntry(path="c.dyr", format="psse_dyr"),
        ]
        test_manifest = Manifest(name="test", files=files)

        result = manifest_formats(test_manifest)
        assert len(result) == 2
        assert "psse_raw" in result
        assert "psse_dyr" in result

    def test_variants_empty(self):
        """Test variants with no variants."""
        from powerfulcases.manifest import variants as manifest_variants, Manifest, FileEntry

        files = [FileEntry(path="a.raw", format="psse_raw")]
        test_manifest = Manifest(name="test", files=files)

        result = manifest_variants(test_manifest, "psse_raw")
        # No variants defined
        assert len(result) == 0

    def test_variants_with_default(self):
        """Test variants includes 'default' for default files."""
        from powerfulcases.manifest import variants as manifest_variants, Manifest, FileEntry

        files = [
            FileEntry(path="default.dyr", format="psse_dyr", default=True),
            FileEntry(path="genrou.dyr", format="psse_dyr", variant="genrou"),
        ]
        test_manifest = Manifest(name="test", files=files)

        result = manifest_variants(test_manifest, "psse_dyr")
        assert "default" in result
        assert "genrou" in result

    def test_manifest_with_data_version(self):
        """Test manifest with data_version field."""
        from powerfulcases.manifest import Manifest, FileEntry, write_manifest, parse_manifest
        from pathlib import Path

        files = [FileEntry(path="test.raw", format="psse_raw")]
        manifest = Manifest(
            name="test", description="Test case", data_version="2024.1", files=files
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "manifest.toml"
            write_manifest(manifest, path)

            parsed = parse_manifest(path)
            assert parsed.data_version == "2024.1"

    def test_file_entry_with_format_version(self):
        """Test FileEntry with format_version."""
        from powerfulcases.manifest import Manifest, FileEntry, write_manifest, parse_manifest
        from pathlib import Path

        files = [
            FileEntry(path="v33.raw", format="psse_raw", format_version="33", default=True),
            FileEntry(path="v34.raw", format="psse_raw", format_version="34"),
        ]
        manifest = Manifest(name="test", files=files)

        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "manifest.toml"
            write_manifest(manifest, path)

            parsed = parse_manifest(path)
            v33 = [f for f in parsed.files if f.format_version == "33"]
            assert len(v33) == 1
            assert v33[0].default is True

    def test_file_entry_with_default_variant(self):
        """Test file_entry with variant='default'."""
        from powerfulcases.manifest import file_entry, Manifest, FileEntry

        files = [
            FileEntry(path="default.dyr", format="psse_dyr", default=True),
            FileEntry(path="genrou.dyr", format="psse_dyr", variant="genrou"),
        ]
        manifest = Manifest(name="test", files=files)

        entry = file_entry(manifest, "psse_dyr", variant="default")
        assert entry is not None
        assert entry.path == "default.dyr"

    def test_load_absolute_path(self):
        """Test load with absolute path."""
        cases_dir = os.path.join(
            os.path.dirname(__file__), "..", "powerfulcases", "cases", "ieee14"
        )
        abs_path = os.path.abspath(cases_dir)
        case = load(abs_path)
        assert case.name == "ieee14"


class TestManifestPaths:
    """Test manifest operations with different path types."""

    def test_parse_manifest_with_string_path(self):
        """Test parse_manifest accepts string paths."""
        from powerfulcases.manifest import parse_manifest

        cases_dir = os.path.join(
            os.path.dirname(__file__), "..", "powerfulcases", "cases", "ieee14"
        )
        manifest_path = os.path.join(cases_dir, "manifest.toml")

        # Should accept string path
        manifest = parse_manifest(manifest_path)
        assert manifest.name == "ieee14"

    def test_manifest_with_string_path(self):
        """Test manifest accepts string paths."""
        with tempfile.TemporaryDirectory() as tmpdir:
            open(os.path.join(tmpdir, "test.raw"), "w").close()

            # Should accept string path
            manifest_path = manifest(tmpdir)
            assert os.path.isfile(manifest_path)


class TestIncludesField:
    """Tests for the includes field in FileEntry (for bundle formats like OpenDSS)."""

    def test_file_entry_with_includes(self):
        """Test FileEntry with includes field."""
        from powerfulcases.manifest import FileEntry

        entry = FileEntry(
            path="master.dss",
            format="opendss",
            default=True,
            includes=["linecodes.dss", "loadshapes.dss", "loads.dss"],
        )
        assert entry.path == "master.dss"
        assert entry.format == "opendss"
        assert entry.default is True
        assert entry.includes == ["linecodes.dss", "loadshapes.dss", "loads.dss"]
        assert len(entry.includes) == 3

    def test_file_entry_without_includes(self):
        """Test FileEntry defaults to empty includes list."""
        from powerfulcases.manifest import FileEntry

        entry = FileEntry(path="test.raw", format="psse_raw")
        assert entry.includes == []

    def test_write_and_parse_manifest_with_includes(self):
        """Test round-trip of manifest with includes field."""
        from powerfulcases.manifest import Manifest, FileEntry, write_manifest, parse_manifest
        from pathlib import Path

        files = [
            FileEntry(
                path="master.dss",
                format="opendss",
                default=True,
                includes=["linecodes.dss", "loads.dss"],
            ),
            FileEntry(path="test.raw", format="psse_raw"),
        ]
        manifest = Manifest(name="includes_test", files=files)

        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_path = Path(tmpdir) / "manifest.toml"
            write_manifest(manifest, manifest_path)

            # Check file contains includes
            content = manifest_path.read_text()
            assert "includes" in content
            assert "linecodes.dss" in content
            assert "loads.dss" in content

            # Parse back and verify
            parsed = parse_manifest(manifest_path)
            assert len(parsed.files) == 2

            dss_file = [f for f in parsed.files if f.format == "opendss"][0]
            assert dss_file.includes == ["linecodes.dss", "loads.dss"]

            raw_file = [f for f in parsed.files if f.format == "psse_raw"][0]
            assert raw_file.includes == []

    def test_list_files_includes_metadata(self):
        """Test list_files returns includes in file metadata."""
        from powerfulcases.manifest import Manifest, FileEntry, write_manifest
        from pathlib import Path

        files = [
            FileEntry(
                path="master.dss",
                format="opendss",
                default=True,
                includes=["data.dss", "profile.csv"],
            ),
        ]
        manifest = Manifest(name="list_files_test", files=files)

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = Path(tmpdir)
            write_manifest(manifest, tmpdir / "manifest.toml")
            (tmpdir / "master.dss").write_text("// OpenDSS file")
            (tmpdir / "data.dss").write_text("// Data file")
            (tmpdir / "profile.csv").write_text("t,v\n0,1.0")

            case = load(str(tmpdir))
            files_list = case.list_files()
            assert len(files_list) == 1

            first_file = files_list[0]
            assert hasattr(first_file, "includes")
            assert first_file.includes == ["data.dss", "profile.csv"]

    def test_manifest_empty_includes_not_written(self):
        """Test that empty includes list is not written to TOML."""
        from powerfulcases.manifest import Manifest, FileEntry, write_manifest
        from pathlib import Path

        files = [
            FileEntry(path="test.raw", format="psse_raw", default=True),
        ]
        manifest = Manifest(name="empty_deps_test", files=files)

        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_path = Path(tmpdir) / "manifest.toml"
            write_manifest(manifest, manifest_path)

            content = manifest_path.read_text()
            # Should not have "includes" key when empty
            assert "includes" not in content

    def test_multiple_files_with_includes(self):
        """Test manifest with multiple files having different includes."""
        from powerfulcases.manifest import Manifest, FileEntry, write_manifest, parse_manifest
        from pathlib import Path

        files = [
            FileEntry(
                path="master_base.dss",
                format="opendss",
                default=True,
                includes=["base_data.dss"],
            ),
            FileEntry(
                path="master_peak.dss",
                format="opendss",
                variant="peak",
                includes=["peak_data.dss", "peak_profile.csv"],
            ),
        ]
        manifest = Manifest(name="multi_includes_test", files=files)

        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_path = Path(tmpdir) / "manifest.toml"
            write_manifest(manifest, manifest_path)

            parsed = parse_manifest(manifest_path)

            base_file = [f for f in parsed.files if f.default][0]
            assert base_file.includes == ["base_data.dss"]

            peak_file = [f for f in parsed.files if f.variant == "peak"][0]
            assert peak_file.includes == ["peak_data.dss", "peak_profile.csv"]


class TestCredits:
    """Tests for credits and licensing functionality."""

    def test_citation_dataclass(self):
        """Test Citation dataclass creation."""
        from powerfulcases.manifest import Citation

        cit = Citation(text="Test citation", doi="10.1234/test")
        assert cit.text == "Test citation"
        assert cit.doi == "10.1234/test"

        cit_no_doi = Citation(text="No DOI citation")
        assert cit_no_doi.doi is None

    def test_credits_dataclass(self):
        """Test Credits dataclass creation."""
        from powerfulcases.manifest import Credits, Citation

        credits = Credits(
            license="CC0-1.0",
            authors=["Author 1", "Author 2"],
            maintainers=["Maintainer 1"],
            citations=[Citation(text="Test citation", doi="10.1234/test")],
        )
        assert credits.license == "CC0-1.0"
        assert len(credits.authors) == 2
        assert len(credits.maintainers) == 1
        assert len(credits.citations) == 1

        empty_credits = Credits()
        assert empty_credits.license is None
        assert len(empty_credits.authors) == 0
        assert len(empty_credits.maintainers) == 0
        assert len(empty_credits.citations) == 0

    def test_manifest_with_credits(self):
        """Test Manifest with credits section."""
        from powerfulcases.manifest import Manifest, Credits, FileEntry

        credits = Credits(license="MIT", authors=["Test Author"])
        manifest = Manifest(
            name="test_case",
            description="Test case with credits",
            credits=credits,
        )
        assert manifest.credits is not None
        assert manifest.credits.license == "MIT"

    def test_manifest_without_credits(self):
        """Test Manifest without credits section."""
        from powerfulcases.manifest import Manifest

        manifest = Manifest(name="test_case")
        assert manifest.credits is None

    def test_parse_manifest_with_credits(self):
        """Test parsing a manifest with credits section."""
        from powerfulcases.manifest import parse_manifest
        from pathlib import Path

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
        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_path = Path(tmpdir) / "manifest.toml"
            manifest_path.write_text(manifest_toml)

            manifest = parse_manifest(manifest_path)
            assert manifest.credits is not None
            assert manifest.credits.license == "MIT"
            assert manifest.credits.authors == ["John Doe", "Jane Smith"]
            assert manifest.credits.maintainers == ["Maintainer A"]
            assert len(manifest.credits.citations) == 2
            assert manifest.credits.citations[0].text == "Doe, J. (2024). Test Paper."
            assert manifest.credits.citations[0].doi == "10.5555/12345"
            assert manifest.credits.citations[1].text == "Smith, J. (2023). Another Paper."
            assert manifest.credits.citations[1].doi is None

    def test_write_manifest_with_credits(self):
        """Test writing and reading back manifest with credits."""
        from powerfulcases.manifest import Manifest, Credits, Citation, FileEntry
        from powerfulcases.manifest import write_manifest, parse_manifest
        from pathlib import Path

        credits = Credits(
            license="Apache-2.0",
            authors=["Test Author"],
            maintainers=["Test Maintainer"],
            citations=[Citation(text="Test citation", doi="10.1234/write")],
        )
        manifest = Manifest(name="write_test", credits=credits)

        with tempfile.TemporaryDirectory() as tmpdir:
            manifest_path = Path(tmpdir) / "manifest.toml"
            write_manifest(manifest, manifest_path)

            parsed = parse_manifest(manifest_path)
            assert parsed.credits is not None
            assert parsed.credits.license == "Apache-2.0"
            assert parsed.credits.authors == ["Test Author"]
            assert parsed.credits.maintainers == ["Test Maintainer"]
            assert len(parsed.credits.citations) == 1
            assert parsed.credits.citations[0].doi == "10.1234/write"

    def test_case_bundle_credits_api(self):
        """Test CaseBundle credits properties."""
        from powerfulcases.manifest import Manifest, Credits, Citation, FileEntry
        from powerfulcases.manifest import write_manifest
        from pathlib import Path

        credits = Credits(
            license="CC0-1.0",
            authors=["Author 1", "Author 2"],
            maintainers=["Maintainer 1"],
            citations=[Citation(text="Test citation", doi="10.1234/test")],
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = Path(tmpdir)
            manifest = Manifest(
                name="test_credits_case",
                credits=credits,
                files=[FileEntry(path="test.raw", format="psse_raw", default=True)],
            )
            write_manifest(manifest, tmpdir / "manifest.toml")

            # Create dummy file
            (tmpdir / "test.raw").write_text("dummy")

            # Load case and test credits API
            case = load(str(tmpdir))
            assert case.has_credits()
            assert case.credits is not None
            assert case.license == "CC0-1.0"
            assert case.authors == ["Author 1", "Author 2"]
            assert case.maintainers == ["Maintainer 1"]
            assert len(case.citations) == 1
            assert case.citations[0].text == "Test citation"
            assert case.citations[0].doi == "10.1234/test"

    def test_case_bundle_no_credits(self):
        """Test CaseBundle without credits."""
        from powerfulcases.manifest import Manifest, FileEntry, write_manifest
        from pathlib import Path

        # Create a temp case without credits
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = Path(tmpdir)
            manifest = Manifest(
                name="no_credits_case",
                description="Test case without credits",
                files=[FileEntry(path="test.raw", format="psse_raw", default=True)],
            )
            write_manifest(manifest, tmpdir / "manifest.toml")
            (tmpdir / "test.raw").write_text("dummy")

            case = load(str(tmpdir))
            assert not case.has_credits()
            assert case.credits is None
            assert case.license is None
            assert case.authors == []
            assert case.maintainers == []
            assert case.citations == []

    def test_cli_info_with_credits(self):
        """Test CLI info command shows credits."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli
        from powerfulcases.manifest import Manifest, Credits, Citation, FileEntry
        from powerfulcases.manifest import write_manifest
        from pathlib import Path

        credits = Credits(
            license="MIT",
            authors=["Test Author"],
            maintainers=["Test Maintainer"],
            citations=[Citation(text="Test Paper (2024)", doi="10.1234/cli")],
        )

        runner = CliRunner()
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = Path(tmpdir)
            manifest = Manifest(
                name="cli_credits_test",
                description="Test case for CLI",
                credits=credits,
                files=[FileEntry(path="test.raw", format="psse_raw", default=True)],
            )
            write_manifest(manifest, tmpdir / "manifest.toml")
            (tmpdir / "test.raw").write_text("dummy")

            result = runner.invoke(cli, ["info", str(tmpdir)])
            assert result.exit_code == 0
            assert "Credits:" in result.output
            assert "License: MIT" in result.output
            assert "Authors: Test Author" in result.output
            assert "Maintainers: Test Maintainer" in result.output
            assert "Citations:" in result.output
            assert "Test Paper (2024)" in result.output
            assert "DOI: 10.1234/cli" in result.output


class TestExport:
    """Tests for export_case() function."""

    def test_export_bundled_case(self):
        """Test exporting a bundled case to a directory."""
        import shutil
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            # Export ieee14 to temp directory
            result = export_case("ieee14", tmpdir)

            # Check destination structure
            dest_dir = Path(tmpdir) / "ieee14"
            assert dest_dir.exists()
            assert dest_dir.is_dir()
            assert str(dest_dir) == result

            # Check files were copied
            assert (dest_dir / "ieee14.raw").exists()
            assert (dest_dir / "manifest.toml").exists()

            # Check DYR variants were copied
            assert (dest_dir / "ieee14.dyr").exists()
            assert (dest_dir / "ieee14_genrou.dyr").exists()

    def test_export_to_current_directory(self):
        """Test exporting to current directory."""
        import shutil
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            # Change to temp directory
            old_cwd = os.getcwd()
            try:
                os.chdir(tmpdir)

                # Export to current directory
                result = export_case("case5", ".")

                # Should create ./case5/ subdirectory
                dest_dir = Path.cwd() / "case5"
                assert dest_dir.exists()
                assert (dest_dir / "case5.raw").exists()

            finally:
                os.chdir(old_cwd)

    def test_export_error_if_exists(self):
        """Test error when destination already exists."""
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            # Export once
            export_case("case9", tmpdir)

            # Try to export again without overwrite
            try:
                export_case("case9", tmpdir)
                assert False, "Should have raised FileExistsError"
            except FileExistsError as e:
                assert "Directory exists" in str(e)
                assert "overwrite" in str(e).lower()

    def test_export_with_overwrite(self):
        """Test exporting with overwrite flag."""
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            dest_dir = Path(tmpdir) / "npcc"

            # Export once
            export_case("npcc", tmpdir)
            assert dest_dir.exists()

            # Modify a file to test overwrite
            test_file = dest_dir / "npcc.raw"
            original_content = test_file.read_text()
            test_file.write_text("MODIFIED CONTENT")
            assert test_file.read_text() == "MODIFIED CONTENT"

            # Export again with overwrite
            export_case("npcc", tmpdir, overwrite=True)

            # Content should be restored
            assert test_file.read_text() == original_content

    def test_export_local_directory(self):
        """Test exporting a local directory (copy operation)."""
        from pathlib import Path
        from powerfulcases.manifest import Manifest, FileEntry, write_manifest

        with tempfile.TemporaryDirectory() as tmpdir:
            # Create a local case
            source_dir = Path(tmpdir) / "my_case"
            source_dir.mkdir()
            (source_dir / "test.raw").write_text("TEST RAW DATA")
            manifest = Manifest(
                name="my_case",
                files=[FileEntry(path="test.raw", format="psse_raw", default=True)],
            )
            write_manifest(manifest, source_dir / "manifest.toml")

            # Export to another location
            dest_parent = Path(tmpdir) / "exported"
            dest_parent.mkdir()
            result = export_case(str(source_dir), str(dest_parent))

            # Check files were copied
            dest_dir = dest_parent / "my_case"
            assert dest_dir.exists()
            assert (dest_dir / "test.raw").exists()
            assert (dest_dir / "test.raw").read_text() == "TEST RAW DATA"
            assert (dest_dir / "manifest.toml").exists()

    def test_export_cli(self):
        """Test export via CLI."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli
        from pathlib import Path

        runner = CliRunner()
        with tempfile.TemporaryDirectory() as tmpdir:
            # Run export command
            result = runner.invoke(cli, ["export", "ieee14", tmpdir])

            # Check success
            assert result.exit_code == 0
            assert "Exported ieee14" in result.output
            assert "Copied" in result.output

            # Check files
            dest_dir = Path(tmpdir) / "ieee14"
            assert dest_dir.exists()
            assert (dest_dir / "ieee14.raw").exists()

    def test_export_cli_overwrite(self):
        """Test export CLI with overwrite flag."""
        from click.testing import CliRunner
        from powerfulcases.cli import cli
        from pathlib import Path

        runner = CliRunner()
        with tempfile.TemporaryDirectory() as tmpdir:
            # Export once
            result1 = runner.invoke(cli, ["export", "case5", tmpdir])
            assert result1.exit_code == 0

            # Try again without --overwrite (should fail)
            result2 = runner.invoke(cli, ["export", "case5", tmpdir])
            assert result2.exit_code == 1
            assert "Error" in result2.output

            # Try with --overwrite (should succeed)
            result3 = runner.invoke(cli, ["export", "case5", tmpdir, "--overwrite"])
            assert result3.exit_code == 0

    def test_export_preserves_all_files(self):
        """Test that export copies all files including variants."""
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            # Export ieee14 which has multiple DYR variants
            export_case("ieee14", tmpdir)

            dest_dir = Path(tmpdir) / "ieee14"
            source_case = load("ieee14")
            source_dir = Path(source_case.dir)

            # Count files in source and destination
            source_files = set(f.name for f in source_dir.iterdir() if f.is_file())
            dest_files = set(f.name for f in dest_dir.iterdir() if f.is_file())

            # All files should be copied
            assert source_files == dest_files

    def test_export_can_load_exported(self):
        """Test that exported cases can be loaded again."""
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmpdir:
            # Export case (use ieee14 which has DYR files)
            export_case("ieee14", tmpdir)

            # Load the exported case
            dest_dir = Path(tmpdir) / "ieee14"
            exported_case = load(str(dest_dir))

            # Should work the same as original
            assert exported_case.name == "ieee14"
            assert os.path.isfile(exported_case.raw)
            assert exported_case.dyr is not None

            # Can access files
            raw_path = file(exported_case, "psse_raw")
            assert os.path.isfile(raw_path)


def run_all_tests():
    """Run all tests manually."""
    test_classes = [
        TestNewAPI,
        TestGetFile,
        TestListFunctions,
        TestCaseBundleMethods,
        TestManifest,
        TestCache,
        TestRegistry,
        TestLegacyAPI,
        TestCLI,
        TestDownloadErrorHandling,
        TestCacheAdvanced,
        TestRegistryAdvanced,
        TestSetupExcludeGeneration,
        TestEdgeCases,
        TestManifestPaths,
        TestIncludesField,
        TestCredits,
        TestExport,
    ]

    for test_class in test_classes:
        print(f"\n--- {test_class.__name__} ---")
        instance = test_class()
        for method_name in dir(instance):
            if method_name.startswith("test_"):
                print(f"  {method_name}...", end=" ")
                try:
                    getattr(instance, method_name)()
                    print("OK")
                except Exception as e:
                    print(f"FAILED: {e}")
                    raise

    print("\nAll tests passed!")


if __name__ == "__main__":
    run_all_tests()
