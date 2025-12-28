function registry = load_registry()
%LOAD_REGISTRY Load the remote cases registry
%   registry = pcase.internal.load_registry() loads the registry.toml file
%   that contains information about remote cases.
%
%   Returns a struct with fields:
%   - remote_cases: cell array of remote case names
%   - base_url: base URL for downloading
%
%   Compatible with both MATLAB and GNU Octave.

    registry = struct();
    registry.remote_cases = {};
    registry.base_url = '';
    registry.version = '0.0.0';

    % Get registry path
    this_file = mfilename('fullpath');
    internal_dir = fileparts(this_file);
    pcase_dir = fileparts(internal_dir);
    matlab_dir = fileparts(pcase_dir);
    pkg_dir = fileparts(matlab_dir);
    registry_path = fullfile(pkg_dir, 'registry.toml');

    if ~pcase.internal.is_file(registry_path)
        return
    end

    % Parse the registry file using shared helper
    lines = pcase.internal.read_lines(registry_path);

    for i = 1:numel(lines)
        line = strtrim(lines{i});

        if isempty(line) || pcase.internal.starts_with(line, '#')
            continue
        end

        % Key-value pair
        eq_idx = strfind(line, '=');
        if ~isempty(eq_idx)
            key = strtrim(line(1:eq_idx(1)-1));
            value_str = strtrim(line(eq_idx(1)+1:end));

            if strcmp(key, 'version')
                registry.version = pcase.internal.parse_toml_value(value_str);
            elseif strcmp(key, 'base_url')
                registry.base_url = pcase.internal.parse_toml_value(value_str);
            elseif strcmp(key, 'remote_cases')
                registry.remote_cases = pcase.internal.parse_toml_value(value_str);
            end
        end
    end
end
