function value = parse_toml_value(str)
%PARSE_TOML_VALUE Parse a TOML value string
%   Handles: booleans, strings (quoted), arrays, numbers, and fallback to string
%   Compatible with both MATLAB and GNU Octave.

    str = strtrim(str);

    % Boolean
    if strcmp(str, 'true')
        value = true;
        return
    elseif strcmp(str, 'false')
        value = false;
        return
    end

    % String (quoted with double or single quotes)
    if length(str) >= 2
        if (str(1) == '"' && str(end) == '"') || ...
           (str(1) == '''' && str(end) == '''')
            value = str(2:end-1);
            return
        end
    end

    % Array
    if length(str) >= 2 && str(1) == '[' && str(end) == ']'
        inner = strtrim(str(2:end-1));
        if isempty(inner)
            value = {};
            return
        end
        % Simple array parsing (strings only)
        parts = strsplit(inner, ',');
        value = {};
        for i = 1:numel(parts)
            p = strtrim(parts{i});
            if length(p) >= 2
                if (p(1) == '"' && p(end) == '"') || ...
                   (p(1) == '''' && p(end) == '''')
                    value{end+1} = p(2:end-1);
                else
                    value{end+1} = p;
                end
            elseif ~isempty(p)
                value{end+1} = p;
            end
        end
        return
    end

    % Number
    num = str2double(str);
    if ~isnan(num)
        value = num;
        return
    end

    % Default: return as string
    value = str;
end
