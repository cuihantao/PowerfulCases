function case_list = cases(varargin)
%CASES List all available case names with optional filtering
%   case_list = pcase.cases() returns a cell array of all available case
%   names, including bundled cases, remote cases, and cached cases.
%
%   case_list = pcase.cases('collection', 'name') filters by collection.
%
%   Arguments (Name-Value pairs):
%       'collection' - Filter by collection name (e.g., 'ieee-transmission')
%
%   Examples:
%       available = pcase.cases();
%       trans_cases = pcase.cases('collection', 'ieee-transmission');
%
%   Compatible with both MATLAB and GNU Octave.

    % Parse arguments
    collection_filter = '';
    for i = 1:2:length(varargin)
        if strcmp(varargin{i}, 'collection')
            collection_filter = varargin{i+1};
        end
    end

    cases_dir = pcase.internal.get_cases_dir();
    case_names = {};
    case_colls = {};

    % Bundled cases - scan recursively
    if pcase.internal.is_folder(cases_dir)
        [case_names, case_colls] = scan_for_cases(cases_dir, cases_dir, case_names, case_colls);
    end

    % Remote cases from registry - extract case names
    registry = pcase.internal.load_registry();
    for i = 1:numel(registry.remote_cases)
        remote_path = registry.remote_cases{i};
        % Extract case name from "collection/case_name" format
        if contains(remote_path, '/')
            parts = strsplit(remote_path, '/');
            case_name = parts{end};
            coll_name = parts{1};
        else
            case_name = remote_path;
            coll_name = '';
        end

        % Check if case name already exists
        idx = find(strcmp(case_names, case_name), 1);
        if isempty(idx)
            case_names{end+1} = case_name;
            case_colls{end+1} = coll_name;
        end
    end

    % Cached cases
    cache_dir = pcase.internal.get_cache_dir();
    if pcase.internal.is_folder(cache_dir)
        entries = dir(cache_dir);
        for i = 1:numel(entries)
            if entries(i).isdir && ~pcase.internal.starts_with(entries(i).name, '.')
                name = entries(i).name;
                % Check if case name already exists
                idx = find(strcmp(case_names, name), 1);
                if isempty(idx)
                    case_names{end+1} = name;
                    case_colls{end+1} = '';
                end
            end
        end
    end

    % Apply filters
    filtered = {};
    for i = 1:numel(case_names)
        name = case_names{i};
        coll = case_colls{i};

        if ~isempty(collection_filter) && ~strcmp(coll, collection_filter)
            continue
        end

        filtered{end+1} = name;
    end

    case_list = sort(filtered);
end

function [case_names, case_colls] = scan_for_cases(root_dir, current_dir, case_names, case_colls)
%SCAN_FOR_CASES Recursively scan for case directories
%   Returns updated case_names and case_colls parallel arrays
    entries = dir(current_dir);
    for i = 1:numel(entries)
        if ~entries(i).isdir || pcase.internal.starts_with(entries(i).name, '.')
            continue
        end

        entry_path = fullfile(current_dir, entries(i).name);

        % Check if this is a case directory (has manifest.toml)
        if pcase.internal.is_file(fullfile(entry_path, 'manifest.toml'))
            case_name = entries(i).name;

            % Determine collection from parent directory
            parent_dir = fileparts(entry_path);
            if strcmp(parent_dir, root_dir)
                coll_name = '';  % Legacy flat case
            else
                [~, coll_name] = fileparts(parent_dir);
            end

            % Check if case name already exists
            idx = find(strcmp(case_names, case_name), 1);
            if isempty(idx)
                case_names{end+1} = case_name;
                case_colls{end+1} = coll_name;
            end
        else
            % Recursively scan subdirectories (collections)
            [case_names, case_colls] = scan_for_cases(root_dir, entry_path, case_names, case_colls);
        end
    end
end
