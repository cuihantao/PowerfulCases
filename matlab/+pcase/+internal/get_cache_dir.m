function cache_dir = get_cache_dir()
%GET_CACHE_DIR Get the PowerfulCases cache directory
%   cache_dir = pcase.internal.get_cache_dir() returns the path to the
%   cache directory where remote cases are stored.
%
%   On Windows: %LOCALAPPDATA%\powerfulcases
%   On Unix/Mac: ~/.powerfulcases
%
%   Compatible with both MATLAB and GNU Octave.

    if ispc
        local_app_data = getenv('LOCALAPPDATA');
        if isempty(local_app_data)
            local_app_data = fullfile(getenv('USERPROFILE'), 'AppData', 'Local');
        end
        cache_dir = fullfile(local_app_data, 'powerfulcases');
    else
        home = getenv('HOME');
        cache_dir = fullfile(home, '.powerfulcases');
    end
end
