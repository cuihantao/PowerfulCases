function download_file(url, dest_path)
%DOWNLOAD_FILE Download a file from a URL
%   pcase.internal.download_file(url, dest_path) downloads a file from the
%   given URL and saves it to dest_path.
%
%   Compatible with both MATLAB and GNU Octave.

    % Ensure parent directory exists
    parent_dir = fileparts(dest_path);
    if ~isempty(parent_dir) && ~pcase.internal.is_folder(parent_dir)
        mkdir(parent_dir);
    end

    % Download file (works in both MATLAB and Octave)
    try
        if exist('websave', 'file')
            % MATLAB
            websave(dest_path, url);
        else
            % Octave - use urlwrite
            urlwrite(url, dest_path);

            % Verify download succeeded (urlwrite may not throw on HTTP errors)
            if ~pcase.internal.is_file(dest_path)
                error('pcase:DownloadError', 'Download failed: file not created');
            end

            file_info = dir(dest_path);
            if isempty(file_info) || file_info.bytes == 0
                error('pcase:DownloadError', 'Download failed: empty file');
            end
        end
    catch ME
        error('pcase:DownloadError', 'Failed to download %s: %s', url, ME.message);
    end
end
