function filepath = file(cb, format, varargin)
%FILE Get the path to a file by format
%   filepath = pcase.file(case, format) returns the path to the default
%   file for the given format.
%
%   filepath = pcase.file(case, format, 'variant', variant) returns the
%   path to a specific variant of the format.
%
%   filepath = pcase.file(case, format, 'required', false) returns empty
%   instead of error if the file is not found.
%
%   Arguments:
%       case   - CaseBundle object
%       format - Format string (e.g., 'psse_raw', 'psse_dyr', 'raw', 'dyr')
%
%   Name-Value Arguments:
%       variant  - Variant name (e.g., 'genrou', 'default')
%       required - If true (default), error if not found; if false, return empty
%
%   Examples:
%       case = pcase.load('ieee14');
%       pcase.file(case, 'psse_raw')
%       pcase.file(case, 'dyr', 'variant', 'genrou')
%       pcase.file(case, 'psse_dyr', 'required', false)
%
%   Compatible with both MATLAB and GNU Octave.

    % Parse arguments
    p = inputParser;
    addRequired(p, 'cb');
    addRequired(p, 'format', @ischar);
    addParameter(p, 'variant', '', @ischar);
    addParameter(p, 'format_version', '', @ischar);
    addParameter(p, 'required', true, @islogical);
    parse(p, cb, format, varargin{:});

    variant = p.Results.variant;
    format_version = p.Results.format_version;
    required = p.Results.required;

    % Normalize format aliases (use shared helper)
    actual_format = pcase.internal.normalize_format(format);

    % Search for matching file
    entry = find_file_entry(cb.manifest, actual_format, format_version, variant);

    if isempty(entry)
        if required
            available = pcase.formats(cb);
            if ~isempty(variant)
                avail_variants = pcase.variants(cb, actual_format);
                error('pcase:FileNotFound', ...
                    'File not found for format ''%s'' with variant ''%s'' in case ''%s''. Available variants: %s', ...
                    format, variant, cb.name, strjoin(avail_variants, ', '));
            elseif ~isempty(format_version)
                error('pcase:FileNotFound', ...
                    'File not found for format ''%s'' with version ''%s'' in case ''%s''. Available formats: %s', ...
                    format, format_version, cb.name, strjoin(available, ', '));
            else
                error('pcase:FileNotFound', ...
                    'File not found for format ''%s'' in case ''%s''. Available formats: %s', ...
                    format, cb.name, strjoin(available, ', '));
            end
        else
            filepath = '';
            return
        end
    end

    filepath = fullfile(cb.dir, entry.path);
end

function entry = find_file_entry(manifest, format, format_version, variant)
%FIND_FILE_ENTRY Find a file entry matching the criteria
%   Logic:
%   - If variant='default', look for files with default=true
%   - If variant=<specific>, look for files with that exact variant
%   - If variant='' (empty), look for default file, then first match
    entry = [];

    % Handle variant='default' specially - look for default=true files
    if strcmp(variant, 'default')
        for i = 1:numel(manifest.files)
            f = manifest.files{i};
            if ~strcmp(f.format, format)
                continue
            end
            if ~isempty(format_version) && ~strcmp(f.format_version, format_version)
                continue
            end
            if f.default
                entry = f;
                return
            end
        end
        return
    end

    % If specific variant requested, match exactly
    if ~isempty(variant)
        for i = 1:numel(manifest.files)
            f = manifest.files{i};
            if ~strcmp(f.format, format)
                continue
            end
            if ~isempty(format_version) && ~strcmp(f.format_version, format_version)
                continue
            end
            if strcmp(f.variant, variant)
                entry = f;
                return
            end
        end
        return
    end

    % No variant specified: prefer default, then first match
    % First pass: look for default=true
    for i = 1:numel(manifest.files)
        f = manifest.files{i};
        if ~strcmp(f.format, format)
            continue
        end
        if ~isempty(format_version) && ~strcmp(f.format_version, format_version)
            continue
        end
        if f.default
            entry = f;
            return
        end
    end

    % Second pass: return first match
    for i = 1:numel(manifest.files)
        f = manifest.files{i};
        if ~strcmp(f.format, format)
            continue
        end
        if ~isempty(format_version) && ~strcmp(f.format_version, format_version)
            continue
        end
        entry = f;
        return
    end
end
