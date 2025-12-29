function dest_dir = export_case(case_name, dest, varargin)
%EXPORT_CASE Export a case bundle to a local directory
%   dest_dir = pcase.export_case(case_name, dest) exports a case bundle
%   to a local directory for modification. The case will be copied to
%   dest/case_name/.
%
%   dest_dir = pcase.export_case(case_name, dest, 'overwrite', true)
%   overwrites an existing directory if present.
%
%   Arguments:
%       case_name - Name of the case to export (e.g., 'ieee14')
%       dest - Destination directory (case will be copied to dest/case_name/)
%
%   Name-Value Arguments:
%       overwrite - If true, overwrite existing directory (default: false)
%
%   Returns:
%       dest_dir - Path to the exported case directory
%
%   Examples:
%       % Export to current directory
%       pcase.export_case('ieee14', '.');
%       % Creates ./ieee14/ with all case files
%
%       % Export to specific project folder
%       pcase.export_case('ieee14', './my-project/cases');
%       % Creates ./my-project/cases/ieee14/
%
%       % Overwrite existing directory
%       pcase.export_case('ieee14', '.', 'overwrite', true);
%
%   The exported case includes:
%     - All case files (.raw, .dyr, etc.)
%     - manifest.toml
%     - All file variants
%     - All included files (e.g., .slx library dependencies)
%     - Symlinks are followed (actual files are copied)
%
%   After export, you can:
%     - Modify case files locally
%     - Add to version control (git)
%     - Load from local path: pcase.load('./ieee14')
%
%   See also: pcase.load, pcase.download
%
%   Compatible with both MATLAB and GNU Octave.

    % Progress threshold (100 MB)
    PROGRESS_THRESHOLD_BYTES = 100 * 1024 * 1024;

    % Parse arguments
    p = inputParser;
    addRequired(p, 'case_name', @ischar);
    addRequired(p, 'dest', @ischar);
    addParameter(p, 'overwrite', false, @islogical);
    parse(p, case_name, dest, varargin{:});
    overwrite = p.Results.overwrite;

    % Load the case (triggers download if needed for remote cases)
    cb = pcase.load(case_name);

    % Determine destination: dest/case_name/
    dest_abs = pcase.internal.get_absolute_path(dest);
    dest_dir = fullfile(dest_abs, cb.name);

    % Create parent directory if needed
    if ~pcase.internal.is_folder(dest_abs)
        mkdir(dest_abs);
    end

    % Check if destination exists
    if pcase.internal.is_folder(dest_dir) && ~overwrite
        error('pcase:DirectoryExists', ...
            ['Directory exists: %s\n' ...
             'Use ''overwrite'', true to replace existing directory'], ...
            dest_dir);
    end

    % Calculate total size for progress reporting
    [file_list, total_size] = get_all_files_and_size(cb.dir);

    % Show progress if size exceeds threshold
    show_progress = total_size > PROGRESS_THRESHOLD_BYTES;

    if show_progress
        size_mb = total_size / (1024 * 1024);
        fprintf('Exporting %s (%.2f MB)...\n', cb.name, size_mb);
    end

    % Remove existing directory if it exists
    if pcase.internal.is_folder(dest_dir)
        if overwrite
            [success, msg] = rmdir(dest_dir, 's');
            if ~success
                error('pcase:RemoveFailed', 'Failed to remove existing directory: %s', msg);
            end
        else
            % Should already be caught above, but defensive check
            error('pcase:DirectoryExists', ...
                ['Directory exists: %s\n' ...
                 'Use ''overwrite'', true to replace existing directory'], ...
                dest_dir);
        end
    end

    % Copy the entire directory
    % MATLAB's copyfile can copy entire directories recursively
    [success, msg] = copyfile(cb.dir, dest_dir);
    if ~success
        error('pcase:CopyFailed', 'Failed to copy directory: %s', msg);
    end

    % Report summary
    num_files = numel(file_list);
    size_mb = total_size / (1024 * 1024);
    fprintf('Exported %s → %s\n', cb.name, dest_dir);
    fprintf('Copied %d files (%.2f MB)\n', num_files, size_mb);
end

function [file_list, total_size] = get_all_files_and_size(dir_path)
%GET_ALL_FILES_AND_SIZE Recursively get all files and total size
    file_list = {};
    total_size = 0;

    % Get all contents recursively
    contents = dir(fullfile(dir_path, '**', '*'));

    for i = 1:numel(contents)
        item = contents(i);
        % Skip directories and special entries
        if ~item.isdir
            filepath = fullfile(item.folder, item.name);
            file_list{end+1} = filepath; %#ok<AGROW>
            total_size = total_size + item.bytes;
        end
    end
end
