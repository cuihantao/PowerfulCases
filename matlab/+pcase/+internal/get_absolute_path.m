function abs_path = get_absolute_path(path)
%GET_ABSOLUTE_PATH Get the absolute path of a file or directory
%   abs_path = get_absolute_path(path) returns the absolute path.
%   Compatible with both MATLAB and GNU Octave.

    % Check if already absolute
    if ispc
        % Windows: check for drive letter (C:\) or UNC path (\\)
        is_abs = (length(path) >= 2 && path(2) == ':') || ...
                 (length(path) >= 2 && path(1) == '\' && path(2) == '\');
    else
        % Unix: starts with /
        is_abs = ~isempty(path) && path(1) == '/';
    end

    if is_abs
        abs_path = path;
    else
        abs_path = fullfile(pwd, path);
    end

    % Normalize the path (resolve . and ..)
    abs_path = canonicalize_path(abs_path);
end

function result = canonicalize_path(path)
%CANONICALIZE_PATH Resolve . and .. in path
    if ispc
        sep = '\';
    else
        sep = '/';
    end

    % Split into parts
    parts = strsplit(path, {'\', '/'});

    % Process parts
    result_parts = {};
    for i = 1:numel(parts)
        p = parts{i};
        if strcmp(p, '.') || isempty(p)
            % Skip . and empty parts (except first empty for Unix root)
            if i == 1 && isempty(p) && ~ispc
                result_parts{end+1} = '';
            end
            continue
        elseif strcmp(p, '..')
            % Go up one level
            if numel(result_parts) > 0 && ~strcmp(result_parts{end}, '..')
                result_parts(end) = [];
            else
                result_parts{end+1} = p;
            end
        else
            result_parts{end+1} = p;
        end
    end

    % Join back
    if isempty(result_parts)
        if ispc
            result = '.';
        else
            result = '/';
        end
    else
        result = strjoin(result_parts, sep);
        % Ensure Unix paths start with /
        if ~ispc && (isempty(result) || result(1) ~= '/')
            result = ['/' result];
        end
    end
end
