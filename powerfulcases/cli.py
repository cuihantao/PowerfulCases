"""
Command-line interface for PowerfulCases.
"""

import click
from pathlib import Path

from .manifest import manifest as _manifest
from .cache import clear as _clear, info as _info
from .registry import download as _download, list_remote_cases


@click.group()
@click.version_option()
def cli():
    """pcase - Power systems test case data management.

    Manage power system case files for simulation and benchmarking.
    Also available as 'powerfulcases' (long form).
    """
    pass


@cli.command("create-manifest")
@click.argument("path", type=click.Path(exists=True, file_okay=False, path_type=Path))
def manifest(path: Path):
    """Generate manifest.toml for a case directory.

    PATH is the directory containing case files (.raw, .dyr, .m, etc.)
    """
    try:
        manifest_path = _manifest(path)
        click.echo(f"Created manifest: {manifest_path}")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        raise SystemExit(1)


@cli.command("download")
@click.argument("name")
@click.option("--force", "-f", is_flag=True, help="Re-download even if cached")
def download(name: str, force: bool):
    """Download a remote case to the local cache.

    NAME is the case name (e.g., 'activsg70k')
    """
    try:
        case_dir = _download(name, force=force)
        click.echo(f"Downloaded to: {case_dir}")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        raise SystemExit(1)


@cli.command("export")
@click.argument("name")
@click.argument("dest", type=click.Path(file_okay=False, path_type=Path))
@click.option("--overwrite", "-f", is_flag=True, help="Overwrite existing directory")
def export_case(name: str, dest: Path, overwrite: bool):
    """Export a case bundle to a local directory.

    NAME is the case name (e.g., 'ieee14')
    DEST is the destination directory (case will be copied to DEST/NAME/)

    Examples:
        pcase export ieee14 .
        pcase export ieee14 ./my-project/cases
        pcase export ieee14 . --overwrite
    """
    from .cases import export_case

    try:
        result_dir = export_case(name, str(dest), overwrite=overwrite)
        # Success message already printed by export function
    except FileExistsError as e:
        click.echo(f"Error: {e}", err=True)
        click.echo("Use --overwrite to replace existing directory", err=True)
        raise SystemExit(1)
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        raise SystemExit(1)


@cli.command("list")
@click.option("--remote", "-r", is_flag=True, help="Show only remote cases")
@click.option("--cached", "-c", is_flag=True, help="Show only cached cases")
def cases(remote: bool, cached: bool):
    """List available cases."""
    from .cases import cases as _cases
    from .cache import list_cached_cases

    if remote:
        cases = list_remote_cases()
        click.echo("Remote cases:")
    elif cached:
        cases = list_cached_cases()
        click.echo("Cached cases:")
    else:
        cases = _cases()
        click.echo("Available cases:")

    for case in cases:
        click.echo(f"  {case}")

    if not cases:
        click.echo("  (none)")


@cli.command("clear-cache")
@click.argument("name", required=False)
@click.option("--all", "-a", "clear_all", is_flag=True, help="Clear entire cache")
def clear(name: str, clear_all: bool):
    """Clear cached cases.

    NAME is the case name to clear. Use --all to clear everything.
    """
    if clear_all:
        if click.confirm("This will delete the entire cache. Continue?"):
            _clear(None)
    elif name:
        _clear(name)
    else:
        click.echo("Specify a case name or use --all to clear everything.")
        raise SystemExit(1)


@cli.command("cache-info")
def info_cmd():
    """Show cache information."""
    info = _info()

    click.echo(f"Cache directory: {info.directory}")
    click.echo(f"Exists: {info.exists}")
    click.echo(f"Number of cached cases: {info.num_cases}")
    click.echo(f"Total size: {info.total_size_mb} MB")

    if info.cases:
        click.echo("Cached cases:")
        for case in info.cases:
            click.echo(f"  {case}")


@cli.command("info")
@click.argument("name")
def case_info(name: str):
    """Show information about a case.

    NAME is the case name (e.g., 'ieee14')
    """
    from .cases import load

    try:
        case = load(name)
        click.echo(f"Case: {case.name}")
        click.echo(f"Directory: {case.dir}")
        click.echo(f"Remote: {case.is_remote}")

        if case.manifest.description:
            click.echo(f"Description: {case.manifest.description}")
        if case.manifest.data_version:
            click.echo(f"Data version: {case.manifest.data_version}")

        # Credits section
        if case.has_credits():
            click.echo("")
            click.echo("Credits:")
            if case.license:
                click.echo(f"  License: {case.license}")
            if case.authors:
                click.echo(f"  Authors: {', '.join(case.authors)}")
            if case.maintainers:
                click.echo(f"  Maintainers: {', '.join(case.maintainers)}")
            if case.citations:
                click.echo("  Citations:")
                for cit in case.citations:
                    click.echo(f"    - {cit.text}")
                    if cit.doi:
                        click.echo(f"      DOI: {cit.doi}")

        click.echo("")
        click.echo("Files:")
        for f in case.manifest.files:
            parts = [f"  {f.path}"]
            parts.append(f"({f.format})")
            if f.format_version:
                parts.append(f"v{f.format_version}")
            if f.variant:
                parts.append(f"[{f.variant}]")
            if f.default:
                parts.append("*default*")
            click.echo(" ".join(parts))

    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        raise SystemExit(1)


def main():
    """Entry point for the CLI."""
    cli()


if __name__ == "__main__":
    main()
