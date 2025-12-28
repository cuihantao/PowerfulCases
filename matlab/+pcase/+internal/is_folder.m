function tf = is_folder(path)
%IS_FOLDER Check if path is a directory
%   tf = is_folder(path) returns true if path exists and is a directory.
%   Compatible with both MATLAB and GNU Octave.

    tf = exist(path, 'dir') == 7;
end
