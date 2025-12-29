function manifest = infer_manifest(case_dir)
%INFER_MANIFEST Auto-detect files in a directory and create a manifest struct
%   manifest = pcase.internal.infer_manifest(case_dir) scans the directory
%   for known file types and returns a manifest struct.
%
%   Compatible with both MATLAB and GNU Octave.

    [~, name] = fileparts(case_dir);
    manifest = struct();
    manifest.name = name;
    manifest.description = '';
    manifest.credits = struct('license', '', 'authors', {{}}, 'maintainers', {{}}, 'citations', {{}});
    manifest.files = {};

    % File extension to format mapping
    ext_formats = struct();
    ext_formats.raw = 'psse_raw';
    ext_formats.dyr = 'psse_dyr';
    ext_formats.m = 'matpower';
    ext_formats.xlsx = 'xlsx';
    ext_formats.csv = 'csv';
    ext_formats.json = 'json';

    % Track which formats we've seen (for default assignment)
    seen_formats = struct();

    % Scan directory
    files = dir(case_dir);
    for i = 1:numel(files)
        if files(i).isdir
            continue
        end

        filename = files(i).name;
        [~, ~, ext] = fileparts(filename);
        ext = lower(ext);

        % Remove leading dot
        if pcase.internal.starts_with(ext, '.')
            ext = ext(2:end);
        end

        % Skip unknown extensions and manifest files
        if strcmp(filename, 'manifest.toml') || ~isfield(ext_formats, ext)
            continue
        end

        format = ext_formats.(ext);

        file_entry = struct();
        file_entry.path = filename;
        file_entry.format = format;
        file_entry.format_version = '';
        file_entry.variant = '';
        file_entry.includes = {};

        % Set as default if first of this format
        if ~isfield(seen_formats, format)
            file_entry.default = true;
            seen_formats.(format) = true;
        else
            file_entry.default = false;
        end

        manifest.files{end+1} = file_entry;
    end
end
