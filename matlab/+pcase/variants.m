function variant_list = variants(cb, format)
%VARIANTS List all variants available for a format
%   variant_list = pcase.variants(case, format) returns a cell array of
%   variant names available for the given format.
%
%   Arguments:
%       case   - CaseBundle object
%       format - Format string (e.g., 'psse_dyr', 'dyr')
%
%   Example:
%       case = pcase.load('ieee14');
%       vars = pcase.variants(case, 'psse_dyr');
%       disp(vars)
%
%   Compatible with both MATLAB and GNU Octave.

    % Normalize format (use shared helper)
    format = pcase.internal.normalize_format(format);

    result = {};
    for i = 1:numel(cb.manifest.files)
        f = cb.manifest.files{i};
        if strcmp(f.format, format)
            if f.default
                if ~ismember('default', result)
                    result{end+1} = 'default';
                end
            elseif ~isempty(f.variant)
                if ~ismember(f.variant, result)
                    result{end+1} = f.variant;
                end
            end
        end
    end
    variant_list = result;
end
