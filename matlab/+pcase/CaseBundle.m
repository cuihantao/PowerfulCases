classdef CaseBundle
%CASEBUNDLE A bundle containing paths to a power system test case
%   A CaseBundle object provides access to test case files and metadata.
%
%   Properties:
%       name      - Case name (e.g., 'ieee14')
%       dir       - Path to case directory
%       manifest  - Parsed manifest struct with file metadata
%       is_remote - True if loaded from remote cache
%
%   Dependent Properties:
%       raw       - Path to the default RAW file
%       dyr       - Path to the default DYR file (or empty)
%       matpower  - Path to the MATPOWER .m file (or empty)
%       psat      - Path to the PSAT file (or empty)
%
%   Example:
%       case = pcase.load('ieee14');
%       disp(case.raw)
%       disp(case.dyr)
%
%   Compatible with both MATLAB and GNU Octave.

    properties
        name = ''           % char array (Octave compatible)
        dir = ''            % char array (Octave compatible)
        manifest = struct() % struct with file metadata
        is_remote = false   % logical
    end

    properties (Dependent)
        raw
        dyr
        matpower  % MATPOWER .m file
        psat      % PSAT file
    end

    methods
        function obj = CaseBundle(name, dir_path, manifest, is_remote)
            %CASEBUNDLE Construct a CaseBundle object
            %   obj = CaseBundle(name, dir_path, manifest, is_remote)
            if nargin >= 1
                obj.name = char(name);
            end
            if nargin >= 2
                obj.dir = char(dir_path);
            end
            if nargin >= 3
                obj.manifest = manifest;
            end
            if nargin >= 4
                obj.is_remote = is_remote;
            end
        end

        function p = get.raw(obj)
            %GET.RAW Get path to the default RAW file
            p = pcase.file(obj, 'psse_raw');
        end

        function p = get.dyr(obj)
            %GET.DYR Get path to the default DYR file (or empty)
            p = pcase.file(obj, 'psse_dyr', 'required', false);
        end

        function p = get.matpower(obj)
            %GET.MATPOWER Get path to the MATPOWER file (or empty)
            p = pcase.file(obj, 'matpower', 'required', false);
        end

        function p = get.psat(obj)
            %GET.PSAT Get path to the PSAT file (or empty)
            p = pcase.file(obj, 'psat', 'required', false);
        end

        function disp(obj)
            %DISP Display CaseBundle information
            fprintf('CaseBundle: %s\n', obj.name);
            fprintf('  Directory: %s\n', obj.dir);
            if obj.is_remote
                fprintf('  Source: remote (cached)\n');
            else
                fprintf('  Source: bundled\n');
            end
            if ~isempty(obj.manifest.description)
                fprintf('  Description: %s\n', obj.manifest.description);
            end
            fprintf('  Files: %d\n', numel(obj.manifest.files));
        end

        % Credits API
        function c = credits(obj)
            %CREDITS Get the credits/attribution information
            c = obj.manifest.credits;
        end

        function tf = has_credits(obj)
            %HAS_CREDITS Check if this case has credits information
            c = obj.manifest.credits;
            tf = ~isempty(c.license) || ~isempty(c.authors);
        end

        function lic = get_license(obj)
            %GET_LICENSE Get the SPDX license identifier (or empty)
            lic = obj.manifest.credits.license;
        end

        function a = get_authors(obj)
            %GET_AUTHORS Get the list of original data authors/creators
            a = obj.manifest.credits.authors;
        end

        function m = get_maintainers(obj)
            %GET_MAINTAINERS Get the list of PowerfulCases maintainers
            m = obj.manifest.credits.maintainers;
        end

        function c = get_citations(obj)
            %GET_CITATIONS Get the list of publications to cite
            c = obj.manifest.credits.citations;
        end
    end
end
