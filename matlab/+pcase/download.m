function case_dir = download(name, varargin)
%DOWNLOAD Download a case from the remote registry
%   case_dir = pcase.download(name) downloads a case from the remote
%   registry and returns the path to the cached case directory.
%
%   case_dir = pcase.download(name, 'force', true) forces re-download
%   even if the case is already cached.
%
%   Arguments:
%       name - Case name to download
%
%   Name-Value Arguments:
%       force - If true, re-download even if cached (default: false)
%
%   Example:
%       pcase.download('ACTIVSg70k');
%       case = pcase.load('ACTIVSg70k');
%
%   Compatible with both MATLAB and GNU Octave.

    % Parse arguments
    p = inputParser;
    addRequired(p, 'name', @ischar);
    addParameter(p, 'force', false, @islogical);
    parse(p, name, varargin{:});
    force = p.Results.force;

    % Load registry
    registry = pcase.internal.load_registry();

    if ~ismember(name, registry.remote_cases)
        available = strjoin(sort(registry.remote_cases), ', ');
        error('pcase:UnknownRemoteCase', ...
            'Unknown remote case: ''%s''. Available: %s', name, available);
    end

    cache_dir = pcase.internal.get_cache_dir();
    case_dir = fullfile(cache_dir, name);

    % Check if already cached
    if ~force && pcase.internal.is_folder(case_dir)
        fprintf('Case ''%s'' already cached at %s\n', name, case_dir);
        return
    end

    % Create cache directory
    if ~pcase.internal.is_folder(cache_dir)
        mkdir(cache_dir);
    end
    if ~pcase.internal.is_folder(case_dir)
        mkdir(case_dir);
    end

    base_url = sprintf('%s/%s', registry.base_url, name);

    % Step 1: Download manifest.toml
    manifest_url = sprintf('%s/manifest.toml', base_url);
    manifest_path = fullfile(case_dir, 'manifest.toml');
    fprintf('Downloading manifest: %s\n', manifest_url);
    pcase.internal.download_file(manifest_url, manifest_path);

    % Step 2: Parse manifest to get file list
    manifest = pcase.internal.parse_manifest(manifest_path);

    if isempty(manifest.files)
        error('pcase:InvalidManifest', ...
            'Manifest for ''%s'' contains no files. This may indicate corrupted remote data.', name);
    end

    % Step 3: Download each file
    for i = 1:numel(manifest.files)
        f = manifest.files{i};
        file_path = f.path;
        file_url = sprintf('%s/%s', base_url, file_path);
        dest_path = fullfile(case_dir, file_path);

        fprintf('Downloading: %s\n', file_path);
        pcase.internal.download_file(file_url, dest_path);
    end

    fprintf('Downloaded case ''%s'' to %s\n', name, case_dir);
end
