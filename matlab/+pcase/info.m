function cache_info = info()
%INFO Show cache status information
%   cache_info = pcase.info() returns a struct with cache information.
%   If called without output arguments, prints the information.
%
%   Returns:
%       struct with fields:
%         - directory: cache directory path
%         - num_cases: number of cached cases
%         - total_size_mb: total size in megabytes
%         - cases: cell array of cached case names
%
%   Example:
%       info = pcase.info();
%       disp(info.directory)
%
%   Compatible with both MATLAB and GNU Octave.

    cache_dir = pcase.internal.get_cache_dir();

    result = struct();
    result.directory = cache_dir;
    result.num_cases = 0;
    result.total_size_mb = 0;
    result.cases = {};

    if pcase.internal.is_folder(cache_dir)
        entries = dir(cache_dir);
        total_bytes = 0;

        for i = 1:numel(entries)
            if entries(i).isdir && ~pcase.internal.starts_with(entries(i).name, '.')
                result.cases{end+1} = entries(i).name;
                result.num_cases = result.num_cases + 1;

                % Calculate size
                case_path = fullfile(cache_dir, entries(i).name);
                files = dir(fullfile(case_path, '**', '*'));
                for j = 1:numel(files)
                    if ~files(j).isdir
                        total_bytes = total_bytes + files(j).bytes;
                    end
                end
            end
        end

        result.total_size_mb = total_bytes / (1024 * 1024);
    end

    if nargout == 0
        fprintf('PowerfulCases Cache\n');
        fprintf('  Directory: %s\n', result.directory);
        fprintf('  Cases: %d\n', result.num_cases);
        fprintf('  Total size: %.2f MB\n', result.total_size_mb);
        if result.num_cases > 0
            fprintf('  Cached: %s\n', strjoin(result.cases, ', '));
        end
    else
        cache_info = result;
    end
end
