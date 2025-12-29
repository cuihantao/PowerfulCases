function collection_list = collections()
%COLLECTIONS List all available collection names
%   collection_list = pcase.collections() returns a cell array of all
%   available collection names.
%
%   Example:
%       colls = pcase.collections();
%       disp(colls)
%
%   Compatible with both MATLAB and GNU Octave.

    result = {};
    cases_dir = pcase.internal.get_cases_dir();

    if pcase.internal.is_folder(cases_dir)
        entries = dir(cases_dir);
        for i = 1:numel(entries)
            if ~entries(i).isdir || pcase.internal.starts_with(entries(i).name, '.')
                continue
            end

            entry_path = fullfile(cases_dir, entries(i).name);
            % Check if it has collection.toml or contains subdirectories
            if pcase.internal.is_file(fullfile(entry_path, 'collection.toml'))
                result{end+1} = entries(i).name;
            else
                % Check for subdirectories
                sub_entries = dir(entry_path);
                has_subdirs = false;
                for j = 1:numel(sub_entries)
                    if sub_entries(j).isdir && ~ismember(sub_entries(j).name, {'.', '..'})
                        has_subdirs = true;
                        break
                    end
                end
                if has_subdirs
                    result{end+1} = entries(i).name;
                end
            end
        end
    end

    collection_list = sort(result);
end
