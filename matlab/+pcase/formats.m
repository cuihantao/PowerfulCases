function format_list = formats(cb)
%FORMATS List all formats available in a case bundle
%   format_list = pcase.formats(case) returns a cell array of format
%   names available in the case bundle.
%
%   Example:
%       case = pcase.load('ieee14');
%       fmts = pcase.formats(case);
%       disp(fmts)
%
%   Compatible with both MATLAB and GNU Octave.

    result = {};
    for i = 1:numel(cb.manifest.files)
        f = cb.manifest.files{i};
        if ~ismember(f.format, result)
            result{end+1} = f.format;
        end
    end
    format_list = result;
end
