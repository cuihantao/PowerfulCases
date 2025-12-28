function cases_dir = get_cases_dir()
%GET_CASES_DIR Get the directory containing bundled cases
%   cases_dir = pcase.internal.get_cases_dir() returns the path to the
%   directory containing bundled PowerfulCases test cases.
%
%   Compatible with both MATLAB and GNU Octave.

    % Get the directory where this file is located
    this_file = mfilename('fullpath');
    internal_dir = fileparts(this_file);
    pcase_dir = fileparts(internal_dir);
    matlab_dir = fileparts(pcase_dir);
    pkg_dir = fileparts(matlab_dir);

    % Cases are in powerfulcases/cases relative to package root
    cases_dir = fullfile(pkg_dir, 'powerfulcases', 'cases');
end
