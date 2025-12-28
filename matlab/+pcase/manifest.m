function manifest(dir_path, varargin)
%MANIFEST Generate a manifest.toml file for a case directory
%   pcase.manifest(dir_path) scans the directory for known file types
%   and generates a manifest.toml file.
%
%   pcase.manifest(dir_path, 'name', 'my_case') specifies the case name.
%   pcase.manifest(dir_path, 'description', 'My case') adds a description.
%   pcase.manifest(dir_path, 'output', 'stdout') prints to console instead.
%
%   Arguments:
%       dir_path - Path to the case directory
%
%   Name-Value Arguments:
%       name        - Case name (default: directory name)
%       description - Case description (default: empty)
%       output      - 'file' (default) or 'stdout'
%
%   Example:
%       pcase.manifest('/path/to/my/case');
%       pcase.manifest('.', 'name', 'ieee14', 'description', 'IEEE 14-bus');
%
%   Compatible with both MATLAB and GNU Octave.

    % Parse arguments
    p = inputParser;
    addRequired(p, 'dir_path', @ischar);
    addParameter(p, 'name', '', @ischar);
    addParameter(p, 'description', '', @ischar);
    addParameter(p, 'output', 'file', @ischar);
    parse(p, dir_path, varargin{:});

    name = p.Results.name;
    description = p.Results.description;
    output_mode = p.Results.output;

    % Get absolute path
    dir_path = pcase.internal.get_absolute_path(dir_path);

    if ~pcase.internal.is_folder(dir_path)
        error('pcase:NotADirectory', 'Not a directory: %s', dir_path);
    end

    % Infer manifest from directory
    m = pcase.internal.infer_manifest(dir_path);

    % Override with user-provided values
    if ~isempty(name)
        m.name = name;
    end
    if ~isempty(description)
        m.description = description;
    end

    % Generate TOML content
    toml = generate_toml(m);

    % Output
    if strcmp(output_mode, 'stdout')
        fprintf('%s', toml);
    else
        manifest_path = fullfile(dir_path, 'manifest.toml');
        fid = fopen(manifest_path, 'w');
        if fid == -1
            error('pcase:FileWriteError', 'Cannot write to: %s', manifest_path);
        end
        fprintf(fid, '%s', toml);
        fclose(fid);
        fprintf('Generated: %s\n', manifest_path);
    end
end

function toml = generate_toml(m)
%GENERATE_TOML Generate TOML string from manifest struct
    lines = {};

    % Header
    lines{end+1} = sprintf('name = "%s"', m.name);
    if ~isempty(m.description)
        lines{end+1} = sprintf('description = "%s"', m.description);
    end
    lines{end+1} = '';

    % Credits section (if any)
    if ~isempty(m.credits.license) || ~isempty(m.credits.authors)
        lines{end+1} = '[credits]';
        if ~isempty(m.credits.license)
            lines{end+1} = sprintf('license = "%s"', m.credits.license);
        end
        if ~isempty(m.credits.authors)
            lines{end+1} = sprintf('authors = [%s]', format_string_array(m.credits.authors));
        end
        if ~isempty(m.credits.maintainers)
            lines{end+1} = sprintf('maintainers = [%s]', format_string_array(m.credits.maintainers));
        end
        lines{end+1} = '';
    end

    % Files
    for i = 1:numel(m.files)
        f = m.files{i};
        lines{end+1} = '[[files]]';
        lines{end+1} = sprintf('path = "%s"', f.path);
        lines{end+1} = sprintf('format = "%s"', f.format);
        if ~isempty(f.format_version)
            lines{end+1} = sprintf('format_version = "%s"', f.format_version);
        end
        if ~isempty(f.variant)
            lines{end+1} = sprintf('variant = "%s"', f.variant);
        end
        if f.default
            lines{end+1} = 'default = true';
        end
        lines{end+1} = '';
    end

    toml = strjoin(lines, sprintf('\n'));
end

function s = format_string_array(arr)
%FORMAT_STRING_ARRAY Format cell array as TOML array of strings
    if isempty(arr)
        s = '';
        return
    end
    quoted = cell(1, numel(arr));
    for i = 1:numel(arr)
        quoted{i} = sprintf('"%s"', arr{i});
    end
    s = strjoin(quoted, ', ');
end
