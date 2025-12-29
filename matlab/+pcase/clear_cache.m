function clear_cache(name)
%CLEAR_CACHE Remove a cached case
%   pcase.clear_cache(name) removes the specified case from the cache.
%   pcase.clear_cache() with no arguments removes all cached cases.
%
%   Arguments:
%       name - (Optional) Case name to remove. If not specified, removes all.
%
%   Example:
%       pcase.clear_cache('ACTIVSg70k');  % Remove specific case
%       pcase.clear_cache();               % Remove all cached cases
%
%   Compatible with both MATLAB and GNU Octave.

    cache_dir = pcase.internal.get_cache_dir();

    if ~pcase.internal.is_folder(cache_dir)
        fprintf('Cache is empty.\n');
        return
    end

    if nargin < 1 || isempty(name)
        % Clear all
        entries = dir(cache_dir);
        for i = 1:numel(entries)
            if entries(i).isdir && ~pcase.internal.starts_with(entries(i).name, '.')
                case_path = fullfile(cache_dir, entries(i).name);
                rmdir(case_path, 's');
                fprintf('Removed: %s\n', entries(i).name);
            end
        end
        fprintf('Cache cleared.\n');
    else
        % Clear specific case
        case_path = fullfile(cache_dir, name);
        if pcase.internal.is_folder(case_path)
            rmdir(case_path, 's');
            fprintf('Removed case ''%s'' from cache.\n', name);
        else
            fprintf('Case ''%s'' not found in cache.\n', name);
        end
    end
end
