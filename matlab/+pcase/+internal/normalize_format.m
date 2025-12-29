function format = normalize_format(format)
%NORMALIZE_FORMAT Normalize format aliases to canonical names
%   Converts short aliases (raw, dyr, dss) to full format names (psse_raw, psse_dyr, opendss)
%   Compatible with both MATLAB and GNU Octave.

    if strcmp(format, 'raw')
        format = 'psse_raw';
    elseif strcmp(format, 'dyr')
        format = 'psse_dyr';
    elseif strcmp(format, 'dss')
        format = 'opendss';
    end
    % Add more aliases here as needed (e.g., 'mp' -> 'matpower')
end
