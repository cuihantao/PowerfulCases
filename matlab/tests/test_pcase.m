function test_pcase()
%TEST_PCASE Comprehensive tests for PowerfulCases MATLAB/Octave API
%   Run with: test_pcase()
%
%   Compatible with both MATLAB and GNU Octave.

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

    % Summary
    fprintf('\n=== Test Summary ===\n');
    fprintf('Passed: %d\n', passed);
    fprintf('Failed: %d\n', failed);
    fprintf('Total:  %d\n', passed + failed);

    if failed > 0
        error('pcase:TestsFailed', '%d tests failed', failed);
    end
end
