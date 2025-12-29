function cb = load(name_or_path)
%LOAD Load a case bundle by name or path
%   case = pcase.load(name) loads a bundled case by name, searching all collections.
%   case = pcase.load('collection/case') loads using explicit collection path.
%   case = pcase.load(path) loads a case from a local directory.
%
%   The API automatically searches all collections to find cases.
%   Users don't need to know which collection a case belongs to.
%
%   Arguments:
%       name_or_path - Case name (e.g., 'ieee14'), collection/case path
%                      (e.g., 'ieee-transmission/ieee14'), or directory path
%
%   Returns:
%       CaseBundle object with access to case files
%
%   Examples:
%       case = pcase.load('ieee14');  % Searches all collections
%       case = pcase.load('ieee-transmission/ieee14');  % Explicit collection
%       case = pcase.load('/path/to/my/case');
%
%   See also: pcase.cases, pcase.collections, pcase.file
%
%   Compatible with both MATLAB and GNU Octave.

    % 1. Check if it's a directory path
    if pcase.internal.is_folder(name_or_path)
        cb = load_local_case(name_or_path);
        return
    end

    cases_dir = pcase.internal.get_cases_dir();

    % 2. Check if it's a collection/case path
    if any(name_or_path == '/')
        parts = strsplit(name_or_path, '/');

        % Validate each path component for security
        for i = 1:numel(parts)
            if strcmp(parts{i}, '..') || strcmp(parts{i}, '.') || ...
               pcase.internal.starts_with(parts{i}, '/') || any(parts{i} == '\')
                error('pcase:InvalidPath', ...
                    'Invalid path component in ''%s''. Path traversal not allowed.', ...
                    name_or_path);
            end
        end

        bundled_dir = fullfile(cases_dir, parts{:});

        % Verify result is within cases_dir
        if pcase.internal.is_folder(bundled_dir)
            bundled_abs = pcase.internal.get_absolute_path(bundled_dir);
            cases_abs = pcase.internal.get_absolute_path(cases_dir);
            if ~pcase.internal.starts_with(bundled_abs, cases_abs)
                error('pcase:SecurityViolation', ...
                    'Attempted path traversal outside cases directory: %s', name_or_path);
            end
            cb = load_bundled_case(parts{end}, bundled_dir);
            return
        end

        % Also check if it's a remote case with collection/case format
        registry = pcase.internal.load_registry();
        if ismember(name_or_path, registry.remote_cases)
            cb = load_remote_case(name_or_path, registry);
            return
        end
    end

    % 3. Collect ALL matches from both bundled and remote sources
    matches = {};  % Cell array of structs: {source_type, collection, location}

    % Bundled matches
    case_dirs = find_case_in_collections(name_or_path, cases_dir);
    for i = 1:numel(case_dirs)
        case_dir = case_dirs{i};
        parent_dir = fileparts(case_dir);
        if strcmp(parent_dir, cases_dir)
            coll_name = '(root)';
        else
            [~, coll_name] = fileparts(parent_dir);
        end
        matches{end+1} = struct('source', 'bundled', 'collection', coll_name, 'location', case_dir);
    end

    % Remote matches
    registry = pcase.internal.load_registry();
    remote_path = find_remote_case_by_name(name_or_path, registry);
    if ~isempty(remote_path)
        % Extract collection from remote_path (e.g., "collection/case")
        if any(remote_path == '/')
            parts = strsplit(remote_path, '/');
            remote_coll = parts{1};
        else
            remote_coll = '(root)';
        end
        matches{end+1} = struct('source', 'remote', 'collection', remote_coll, 'location', remote_path);
    end

    % Check for ambiguity across ALL sources
    if numel(matches) > 1
        sources = cell(1, numel(matches));
        for i = 1:numel(matches)
            sources{i} = sprintf('%s:%s', matches{i}.source, matches{i}.collection);
        end
        error('pcase:AmbiguousCase', ...
            'Ambiguous case name ''%s'' found in multiple locations: %s. Use collection/case format.', ...
            name_or_path, strjoin(sources, ', '));
    end

    % Load the single match
    if numel(matches) == 1
        match = matches{1};
        if strcmp(match.source, 'bundled')
            cb = load_bundled_case(name_or_path, match.location);
        else  % remote
            cb = load_remote_case(match.location, registry);
        end
        return
    end

    % Not found
    available = pcase.cases();
    error('pcase:UnknownCase', ...
        'Unknown case: ''%s''. Available: %s', ...
        name_or_path, strjoin(available(1:min(10,end)), ', '));
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

function cb = load_remote_case(name_or_path, registry)
%LOAD_REMOTE_CASE Load a remote case, downloading if necessary
    cache_dir = pcase.internal.get_cache_dir();
    case_dir = fullfile(cache_dir, name_or_path);

    % Check if cached
    if ~pcase.internal.is_folder(case_dir)
        pcase.download(name_or_path);
    end

    manifest_path = fullfile(case_dir, 'manifest.toml');
    if pcase.internal.is_file(manifest_path)
        manifest = pcase.internal.parse_manifest(manifest_path);
    else
        manifest = pcase.internal.infer_manifest(case_dir);
    end

    % Extract case name from "collection/case_name" or use as-is
    if any(name_or_path == '/')
        parts = strsplit(name_or_path, '/');
        case_name = parts{end};
    else
        case_name = name_or_path;
    end

    cb = pcase.CaseBundle(case_name, case_dir, manifest, true);
end

function case_dirs = find_case_in_collections(case_name, cases_dir)
%FIND_CASE_IN_COLLECTIONS Search all collection directories for a case by name
%   Returns cell array of all matching case directory paths
    case_dirs = {};

    if ~pcase.internal.is_folder(cases_dir)
        return
    end

    % Check top-level (legacy flat structure)
    top_level_case = fullfile(cases_dir, case_name);
    if pcase.internal.is_folder(top_level_case)
        case_dirs{end+1} = top_level_case;
    end

    % Search collection subdirectories
    entries = dir(cases_dir);
    for i = 1:numel(entries)
        if ~entries(i).isdir || pcase.internal.starts_with(entries(i).name, '.')
            continue
        end

        coll_path = fullfile(cases_dir, entries(i).name);
        case_dir = fullfile(coll_path, case_name);
        if pcase.internal.is_folder(case_dir)
            case_dirs{end+1} = case_dir;
        end
    end
end

function remote_path = find_remote_case_by_name(case_name, registry)
%FIND_REMOTE_CASE_BY_NAME Search remote_cases for a case by name
%   Returns full "collection/case_name" path if found, empty string otherwise
    remote_path = '';
    matches = {};

    for i = 1:numel(registry.remote_cases)
        remote_entry = registry.remote_cases{i};
        % Extract case name from "collection/case_name" format
        if any(remote_entry == '/')
            parts = strsplit(remote_entry, '/');
            remote_case_name = parts{end};
        else
            remote_case_name = remote_entry;
        end

        if strcmp(remote_case_name, case_name)
            matches{end+1} = remote_entry;
        end
    end

    if numel(matches) > 1
        error('pcase:AmbiguousRemoteCase', ...
            'Ambiguous remote case ''%s'' found in multiple collections: %s', ...
            case_name, strjoin(matches, ', '));
    end

    if numel(matches) == 1
        remote_path = matches{1};
    end
end
