function pcase_install()
%PCASE_INSTALL Add PowerfulCases MATLAB API to the MATLAB path
%   pcase_install() adds the matlab/ folder to the MATLAB path so that
%   you can use pcase.load(), pcase.file(), etc.
%
%   Run this once after downloading PowerfulCases, or add it to your
%   startup.m file.
%
%   Example:
%       % One-time setup
%       pcase_install();
%
%       % Then use the API
%       case = pcase.load('ieee14');
%       disp(case.raw)

    % Get the directory containing this file
    this_file = mfilename('fullpath');
    pkg_dir = fileparts(this_file);

    % Add matlab/ to path
    matlab_dir = fullfile(pkg_dir, 'matlab');

    if ~isfolder(matlab_dir)
        error('pcase:InstallError', ...
            'matlab/ folder not found at %s', matlab_dir);
    end

    addpath(matlab_dir);
    fprintf('Added %s to MATLAB path.\n', matlab_dir);
    fprintf('You can now use pcase.load(), pcase.file(), etc.\n');
    fprintf('\nExample:\n');
    fprintf('  case = pcase.load(''ieee14'');\n');
    fprintf('  disp(case.raw)\n');
end
