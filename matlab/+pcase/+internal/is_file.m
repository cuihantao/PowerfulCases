function tf = is_file(path)
%IS_FILE Check if path is a file
%   tf = is_file(path) returns true if path exists and is a file.
%   Compatible with both MATLAB and GNU Octave.

    tf = exist(path, 'file') == 2;
end
