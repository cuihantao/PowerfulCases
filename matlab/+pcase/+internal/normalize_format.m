function format = normalize_format(format)
%NORMALIZE_FORMAT Normalize format aliases to canonical names
%   Converts short aliases (raw, dyr) to full format names (psse_raw, psse_dyr)
%   Compatible with both MATLAB and GNU Octave.

    if strcmp(format, 'raw')
        format = 'psse_raw';
    elseif strcmp(format, 'dyr')
        format = 'psse_dyr';
    end
    % Add more aliases here as needed (e.g., 'mp' -> 'matpower')
end
