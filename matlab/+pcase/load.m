function cb = load(name_or_path)
%LOAD Load a case bundle by name or path
%   case = pcase.load(name) loads a bundled case by name.
%   case = pcase.load(path) loads a case from a local directory.
%
%   Arguments:
%       name_or_path - Either a case name (e.g., 'ieee14') or a path to
%                      a local directory containing case files
%
%   Returns:
%       CaseBundle object with access to case files
%
%   Examples:
%       case = pcase.load('ieee14');
%       case = pcase.load('/path/to/my/case');
%
%   See also: pcase.cases, pcase.file
%
%   Compatible with both MATLAB and GNU Octave.

    % Check if it's a directory path
    if pcase.internal.is_folder(name_or_path)
        cb = load_local_case(name_or_path);
        return
    end

    % Check if it's a bundled case
    cases_dir = pcase.internal.get_cases_dir();
    bundled_dir = fullfile(cases_dir, name_or_path);
    if pcase.internal.is_folder(bundled_dir)
        cb = load_bundled_case(name_or_path, bundled_dir);
        return
    end

    % Check if it's a remote case
    registry = pcase.internal.load_registry();
    if ismember(name_or_path, registry.remote_cases)
        cb = load_remote_case(name_or_path, registry);
        return
    end

    % Not found
    available = pcase.cases();
    error('pcase:UnknownCase', ...
        'Unknown case: ''%s''. Available cases: %s', ...
        name_or_path, strjoin(available, ', '));
end

function cb = load_bundled_case(name, dir_path)
%LOAD_BUNDLED_CASE Load a bundled case from the package
    manifest_path = fullfile(dir_path, 'manifest.toml');
    if pcase.internal.is_file(manifest_path)
        manifest = pcase.internal.parse_manifest(manifest_path);
    else
        manifest = pcase.internal.infer_manifest(dir_path);
    end
    cb = pcase.CaseBundle(name, dir_path, manifest, false);
end

function cb = load_local_case(dir_path)
%LOAD_LOCAL_CASE Load a case from a local directory
    [~, name] = fileparts(dir_path);
    dir_path = pcase.internal.get_absolute_path(dir_path);

    manifest_path = fullfile(dir_path, 'manifest.toml');
    if pcase.internal.is_file(manifest_path)
        manifest = pcase.internal.parse_manifest(manifest_path);
    else
        manifest = pcase.internal.infer_manifest(dir_path);
    end
    cb = pcase.CaseBundle(name, dir_path, manifest, false);
end

function cb = load_remote_case(name, registry)
%LOAD_REMOTE_CASE Load a remote case, downloading if necessary
    cache_dir = pcase.internal.get_cache_dir();
    case_dir = fullfile(cache_dir, name);

    % Check if cached
    if ~pcase.internal.is_folder(case_dir)
        pcase.download(name);
    end

    manifest_path = fullfile(case_dir, 'manifest.toml');
    if pcase.internal.is_file(manifest_path)
        manifest = pcase.internal.parse_manifest(manifest_path);
    else
        manifest = pcase.internal.infer_manifest(case_dir);
    end
    cb = pcase.CaseBundle(name, case_dir, manifest, true);
end
