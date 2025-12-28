function tf = starts_with(str, prefix)
%STARTS_WITH Check if string starts with prefix
%   tf = starts_with(str, prefix) returns true if str starts with prefix.
%   Compatible with both MATLAB and GNU Octave.

    if isempty(prefix)
        tf = true;
        return
    end
    if length(str) < length(prefix)
        tf = false;
        return
    end
    tf = strncmp(str, prefix, length(prefix));
end
