function case_list = cases()
%CASES List all available case names
%   case_list = pcase.cases() returns a cell array of all available case
%   names, including bundled cases, remote cases, and cached cases.
%
%   Example:
%       available = pcase.cases();
%       disp(available)
%
%   Compatible with both MATLAB and GNU Octave.

    result = {};

    % Bundled cases
    cases_dir = pcase.internal.get_cases_dir();
    if pcase.internal.is_folder(cases_dir)
        entries = dir(cases_dir);
        for i = 1:numel(entries)
            if entries(i).isdir && ~pcase.internal.starts_with(entries(i).name, '.')
                result{end+1} = entries(i).name;
            end
        end
    end

    % Remote cases from registry
    registry = pcase.internal.load_registry();
    for i = 1:numel(registry.remote_cases)
        name = registry.remote_cases{i};
        if ~ismember(name, result)
            result{end+1} = name;
        end
    end

    % Cached cases
    cache_dir = pcase.internal.get_cache_dir();
    if pcase.internal.is_folder(cache_dir)
        entries = dir(cache_dir);
        for i = 1:numel(entries)
            if entries(i).isdir && ~pcase.internal.starts_with(entries(i).name, '.')
                name = entries(i).name;
                if ~ismember(name, result)
                    result{end+1} = name;
                end
            end
        end
    end

    % Sort
    case_list = sort(result);
end
