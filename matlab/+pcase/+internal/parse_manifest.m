function manifest = parse_manifest(filepath)
%PARSE_MANIFEST Parse a manifest.toml file into a struct
%   manifest = pcase.internal.parse_manifest(filepath) reads the manifest.toml
%   file and returns a struct with fields: name, description, credits, files
%
%   This is a simple TOML parser sufficient for PowerfulCases manifest files.
%   Compatible with both MATLAB and GNU Octave.

    manifest = struct();
    manifest.name = '';
    manifest.description = '';
    manifest.credits = struct('license', '', 'authors', {{}}, 'maintainers', {{}}, 'citations', {{}});
    manifest.files = {};

    if ~pcase.internal.is_file(filepath)
        error('pcase:FileNotFound', 'Manifest file not found: %s', filepath);
    end

    lines = pcase.internal.read_lines(filepath);
    current_section = '';
    current_file = struct();
    in_file_block = false;

    i = 1;
    while i <= numel(lines)
        line = strtrim(lines{i});

        % Skip empty lines and comments
        if isempty(line) || pcase.internal.starts_with(line, '#')
            i = i + 1;
            continue
        end

        % Array of tables: [[files]] or [[credits.citations]]
        if length(line) >= 4 && strcmp(line(1:2), '[[') && strcmp(line(end-1:end), ']]')
            % Save previous file if we were in a file block
            if in_file_block && ~isempty(fieldnames(current_file))
                manifest.files{end+1} = current_file;
            end

            section_name = line(3:end-2);
            if strcmp(section_name, 'files')
                current_section = 'files';
                current_file = struct('path', '', 'format', '', 'format_version', '', ...
                                      'variant', '', 'default', false, 'includes', {{}});
                in_file_block = true;
            elseif strcmp(section_name, 'credits.citations')
                current_section = 'credits.citations';
                in_file_block = false;
                % Create new citation entry immediately
                manifest.credits.citations{end+1} = struct();
            end
            i = i + 1;
            continue
        end

        % Table header: [credits]
        if length(line) >= 2 && line(1) == '[' && line(end) == ']' && ...
           (length(line) < 2 || line(2) ~= '[')
            % Save previous file if we were in a file block
            if in_file_block && ~isempty(fieldnames(current_file))
                manifest.files{end+1} = current_file;
                in_file_block = false;
            end

            current_section = line(2:end-1);
            i = i + 1;
            continue
        end

        % Key-value pair
        eq_idx = strfind(line, '=');
        if ~isempty(eq_idx)
            key = strtrim(line(1:eq_idx(1)-1));
            value_str = strtrim(line(eq_idx(1)+1:end));

            % Handle multi-line arrays: accumulate lines until brackets match
            if ~isempty(value_str) && value_str(1) == '['
                open_count = sum(value_str == '[') - sum(value_str == ']');
                while open_count > 0 && i < numel(lines)
                    i = i + 1;
                    next_line = strtrim(lines{i});
                    % Skip comment lines inside array
                    if ~isempty(next_line) && next_line(1) ~= '#'
                        value_str = [value_str, ' ', next_line];
                        open_count = open_count + sum(next_line == '[') - sum(next_line == ']');
                    end
                end
            end

            value = pcase.internal.parse_toml_value(value_str);

            if isempty(current_section)
                % Top-level keys
                manifest.(key) = value;
            elseif strcmp(current_section, 'credits')
                manifest.credits.(key) = value;
            elseif strcmp(current_section, 'credits.citations')
                % Add key-value to the current (last) citation
                last_idx = numel(manifest.credits.citations);
                if last_idx > 0
                    manifest.credits.citations{last_idx}.(key) = value;
                end
            elseif strcmp(current_section, 'files') && in_file_block
                current_file.(key) = value;
            end
        end
        i = i + 1;
    end

    % Save last file if we were in a file block
    if in_file_block && ~isempty(fieldnames(current_file)) && ~isempty(current_file.path)
        manifest.files{end+1} = current_file;
    end
end
