function test_pcase()
%TEST_PCASE Comprehensive tests for PowerfulCases MATLAB/Octave API
%   Run with: test_pcase()
%
%   Compatible with both MATLAB and GNU Octave.

    % Suppress Octave warning about pcase.load shadowing built-in load.
    % This is expected: users call pcase.load(), not bare load().
    if exist('OCTAVE_VERSION', 'builtin')
        warning('off', 'Octave:shadowed-function');
    end

    fprintf('=== PowerfulCases MATLAB/Octave API Tests ===\n\n');

    passed = 0;
    failed = 0;

    % Test 1: pcase.cases() returns available cases
    try
        fprintf('Test 1: pcase.cases()... ');
        case_list = pcase.cases();
        assert(iscell(case_list), 'cases() should return cell array');
        assert(ismember('ieee14', case_list), 'ieee14 should be in cases list');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 2: pcase.load() bundled case
    try
        fprintf('Test 2: pcase.load(''ieee14'')... ');
        c = pcase.load('ieee14');
        assert(strcmp(c.name, 'ieee14'), 'name should be ieee14');
        assert(~isempty(c.dir), 'dir should not be empty');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 3: CaseBundle.raw property
    try
        fprintf('Test 3: case.raw property... ');
        c = pcase.load('ieee14');
        raw_path = c.raw;
        assert(~isempty(raw_path), 'raw should not be empty');
        assert(exist(raw_path, 'file') == 2, 'raw file should exist');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 4: CaseBundle.dyr property (optional)
    try
        fprintf('Test 4: case.dyr property... ');
        c = pcase.load('ieee14');
        dyr_path = c.dyr;
        % dyr may be empty if case doesn't have DYR files
        if ~isempty(dyr_path)
            assert(exist(dyr_path, 'file') == 2, 'dyr file should exist if path given');
        end
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 5: pcase.file() function
    try
        fprintf('Test 5: pcase.file()... ');
        c = pcase.load('ieee14');
        raw_path = pcase.file(c, 'psse_raw');
        assert(~isempty(raw_path), 'file() should return path');
        assert(exist(raw_path, 'file') == 2, 'file should exist');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 6: pcase.file() with format alias
    try
        fprintf('Test 6: pcase.file() with alias... ');
        c = pcase.load('ieee14');
        raw1 = pcase.file(c, 'raw');
        raw2 = pcase.file(c, 'psse_raw');
        assert(strcmp(raw1, raw2), 'raw alias should work');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 7: pcase.file() required=false
    try
        fprintf('Test 7: pcase.file() required=false... ');
        c = pcase.load('ieee14');
        result = pcase.file(c, 'nonexistent_format', 'required', false);
        assert(isempty(result), 'should return empty for missing format');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 8: pcase.formats()
    try
        fprintf('Test 8: pcase.formats()... ');
        c = pcase.load('ieee14');
        fmts = pcase.formats(c);
        assert(iscell(fmts), 'formats() should return cell array');
        assert(ismember('psse_raw', fmts), 'psse_raw should be in formats');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 9: pcase.variants()
    try
        fprintf('Test 9: pcase.variants()... ');
        c = pcase.load('ieee14');
        vars = pcase.variants(c, 'psse_dyr');
        assert(iscell(vars), 'variants() should return cell array');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 10: pcase.info()
    try
        fprintf('Test 10: pcase.info()... ');
        info_struct = pcase.info();
        assert(isstruct(info_struct), 'info() should return struct');
        assert(isfield(info_struct, 'directory'), 'should have directory field');
        assert(isfield(info_struct, 'num_cases'), 'should have num_cases field');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 11: CaseBundle.manifest property
    try
        fprintf('Test 11: case.manifest property... ');
        c = pcase.load('ieee14');
        m = c.manifest;
        assert(isstruct(m), 'manifest should be struct');
        assert(isfield(m, 'files'), 'manifest should have files field');
        assert(iscell(m.files), 'files should be cell array');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 12: Credits API
    try
        fprintf('Test 12: Credits API... ');
        c = pcase.load('ieee14');
        cred = c.credits();
        assert(isstruct(cred), 'credits() should return struct');
        tf = c.has_credits();
        assert(islogical(tf), 'has_credits() should return logical');
        lic = c.get_license();
        % license may be empty
        authors = c.get_authors();
        assert(iscell(authors), 'get_authors() should return cell array');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 13: Error handling - unknown case
    try
        fprintf('Test 13: Error on unknown case... ');
        try
            pcase.load('nonexistent_case_xyz');
            fprintf('FAILED: should have thrown error\n');
            failed = failed + 1;
        catch
            fprintf('PASSED\n');
            passed = passed + 1;
        end
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 14: CaseBundle display
    try
        fprintf('Test 14: CaseBundle disp()... ');
        c = pcase.load('ieee14');
        % Just check it doesn't error
        disp(c);
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 15: export_case basic functionality
    try
        fprintf('Test 15: pcase.export_case()... ');
        tmpdir = tempname();
        mkdir(tmpdir);
        try
            dest = pcase.export_case('ieee14', tmpdir);
            assert(pcase.internal.is_folder(dest), 'exported directory should exist');
            expected = fullfile(tmpdir, 'ieee14');
            assert(strcmp(dest, expected), 'should export to dest/case_name/');
            rmdir(tmpdir, 's');
            fprintf('PASSED\n');
            passed = passed + 1;
        catch ME
            if pcase.internal.is_folder(tmpdir)
                rmdir(tmpdir, 's');
            end
            rethrow(ME);
        end
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 16: export_case creates all files
    try
        fprintf('Test 16: export_case includes all files... ');
        tmpdir = tempname();
        mkdir(tmpdir);
        try
            dest = pcase.export_case('ieee14', tmpdir);
            % Check that RAW file exists
            raw_exists = pcase.internal.is_file(fullfile(dest, 'ieee14.raw'));
            assert(raw_exists, 'RAW file should exist in exported directory');
            % Check manifest exists
            manifest_exists = pcase.internal.is_file(fullfile(dest, 'manifest.toml'));
            assert(manifest_exists, 'manifest.toml should exist');
            rmdir(tmpdir, 's');
            fprintf('PASSED\n');
            passed = passed + 1;
        catch ME
            if pcase.internal.is_folder(tmpdir)
                rmdir(tmpdir, 's');
            end
            rethrow(ME);
        end
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 17: export_case fails when directory exists
    try
        fprintf('Test 17: export_case errors on existing dir... ');
        tmpdir = tempname();
        mkdir(tmpdir);
        try
            pcase.export_case('ieee14', tmpdir);
            % Try to export again without overwrite - should fail
            try
                pcase.export_case('ieee14', tmpdir);
                fprintf('FAILED: should have thrown error\n');
                failed = failed + 1;
                rmdir(tmpdir, 's');
            catch
                rmdir(tmpdir, 's');
                fprintf('PASSED\n');
                passed = passed + 1;
            end
        catch ME
            if pcase.internal.is_folder(tmpdir)
                rmdir(tmpdir, 's');
            end
            rethrow(ME);
        end
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 18: export_case with overwrite
    try
        fprintf('Test 18: export_case with overwrite... ');
        tmpdir = tempname();
        mkdir(tmpdir);
        try
            dest1 = pcase.export_case('ieee14', tmpdir);
            % Export again with overwrite=true - should succeed
            dest2 = pcase.export_case('ieee14', tmpdir, 'overwrite', true);
            assert(strcmp(dest1, dest2), 'should return same path');
            assert(pcase.internal.is_folder(dest2), 'directory should still exist');
            rmdir(tmpdir, 's');
            fprintf('PASSED\n');
            passed = passed + 1;
        catch ME
            if pcase.internal.is_folder(tmpdir)
                rmdir(tmpdir, 's');
            end
            rethrow(ME);
        end
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 19: exported case can be loaded
    try
        fprintf('Test 19: load exported case... ');
        tmpdir = tempname();
        mkdir(tmpdir);
        try
            dest = pcase.export_case('ieee14', tmpdir);
            % Load from exported directory
            c = pcase.load(dest);
            assert(strcmp(c.name, 'ieee14'), 'loaded case should have correct name');
            assert(~isempty(c.raw), 'loaded case should have RAW file');
            rmdir(tmpdir, 's');
            fprintf('PASSED\n');
            passed = passed + 1;
        catch ME
            if pcase.internal.is_folder(tmpdir)
                rmdir(tmpdir, 's');
            end
            rethrow(ME);
        end
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 20: export_case creates parent directories
    try
        fprintf('Test 20: export_case creates parent dirs... ');
        tmpbase = tempname();
        tmpdir = fullfile(tmpbase, 'nested', 'path');
        try
            dest = pcase.export_case('ieee14', tmpdir);
            expected = fullfile(tmpdir, 'ieee14');
            assert(strcmp(dest, expected), 'should return correct nested path');
            assert(pcase.internal.is_folder(dest), 'nested directory should exist');
            assert(pcase.internal.is_file(fullfile(dest, 'ieee14.raw')), 'RAW file should exist');
            rmdir(tmpbase, 's');
            fprintf('PASSED\n');
            passed = passed + 1;
        catch ME
            if pcase.internal.is_folder(tmpbase)
                rmdir(tmpbase, 's');
            end
            rethrow(ME);
        end
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 21: pcase.collections()
    try
        fprintf('Test 21: pcase.collections()... ');
        colls = pcase.collections();
        assert(iscell(colls), 'collections() should return cell array');
        assert(~isempty(colls), 'should have at least one collection');
        assert(ismember('ieee-transmission', colls), 'should include ieee-transmission');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 22: pcase.cases() with collection filter
    try
        fprintf('Test 22: pcase.cases(''collection'', ...)... ');
        trans_cases = pcase.cases('collection', 'ieee-transmission');
        assert(iscell(trans_cases), 'filtered cases should be cell array');
        assert(numel(trans_cases) == 8, 'ieee-transmission should have 8 cases');
        assert(ismember('ieee14', trans_cases), 'should include ieee14');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 23: pcase.load() searches collections
    try
        fprintf('Test 23: load searches collections... ');
        c = pcase.load('ieee14');
        assert(strcmp(c.name, 'ieee14'), 'should load ieee14');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 24: pcase.load() with collection/case path
    try
        fprintf('Test 24: load(''collection/case'')... ');
        c = pcase.load('ieee-transmission/ieee14');
        assert(strcmp(c.name, 'ieee14'), 'should load ieee14');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 25: cases() returns all 88 cases
    try
        fprintf('Test 25: cases() returns all cases... ');
        all_cases = pcase.cases();
        assert(numel(all_cases) == 88, 'should have 88 total cases');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 26: Synthetic collection filter
    try
        fprintf('Test 26: synthetic collection filter... ');
        synth_cases = pcase.cases('collection', 'synthetic');
        assert(iscell(synth_cases), 'should return cell array');
        assert(numel(synth_cases) == 10, 'synthetic should have 10 cases');
        assert(ismember('ACTIVSg2000', synth_cases), 'should include ACTIVSg2000');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Test 27: Nonexistent collection returns empty
    try
        fprintf('Test 27: nonexistent collection... ');
        result = pcase.cases('collection', 'nonexistent');
        assert(iscell(result), 'should return cell array');
        assert(isempty(result), 'should be empty for nonexistent collection');
        fprintf('PASSED\n');
        passed = passed + 1;
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        failed = failed + 1;
    end

    % Summary
    fprintf('\n=== Test Summary ===\n');
    fprintf('Passed: %d\n', passed);
    fprintf('Failed: %d\n', failed);
    fprintf('Total:  %d\n', passed + failed);

    if failed > 0
        error('pcase:TestsFailed', '%d tests failed', failed);
    end
end
