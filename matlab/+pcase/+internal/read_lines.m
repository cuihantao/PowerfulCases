function lines = read_lines(filepath)
%READ_LINES Read all lines from a text file
%   lines = read_lines(filepath) returns a cell array of strings, one per line.
%   Compatible with both MATLAB and GNU Octave.

    lines = {};
    fid = fopen(filepath, 'r');
    if fid == -1
        error('pcase:FileReadError', 'Cannot open file: %s', filepath);
    end

    try
        while true
            line = fgetl(fid);
            if ~ischar(line)
                break  % EOF
            end
            lines{end+1} = line;
        end
    catch ME
        fclose(fid);
        rethrow(ME);
    end

    fclose(fid);
end
