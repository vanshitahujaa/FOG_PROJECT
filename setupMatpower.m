% % MATPOWER SETUP AND VERIFICATION SCRIPT %
        Run this script to set up MATPOWER and verify installation % % Usage : %
    >> setupMatpower % >> setupMatpower('/custom/path/to/matpower')

                              function setupMatpower(customPath) fprintf('\n');
fprintf('==========================================================\n');
fprintf('   MATPOWER SETUP FOR FOG-ASSISTED FDIA DETECTION\n');
fprintf('==========================================================\n');
fprintf('\n');

% %
    Step 1
    : Check if MATPOWER is already installed
          fprintf('Step 1: Checking existing MATPOWER installation...\n');

if exist ('loadcase', 'file')
  &&exist('runpf', 'file')
      fprintf('✓ MATPOWER is already installed and accessible!\n');
verifyInstallation();
return;
end

    % %
    Step 2
    : Try common installation paths
          fprintf('Step 2: Searching for MATPOWER in common locations...\n');

commonPaths = {
    '/Applications/MATLAB/toolbox/matpower',
    '~/Documents/MATLAB/matpower',
    '~/matpower',
    '/usr/local/matpower',
    'C:\Program Files\MATLAB\toolbox\matpower',
    'C:\matpower',
};

if nargin
  >= 1 && ~isempty(customPath) commonPaths = [ {customPath}, commonPaths ];
end

    matpowerPath = '';
    for
      i = 1 : length(commonPaths) testPath = commonPaths{i};
    if exist (testPath, 'dir')
      % Check if it contains MATPOWER files if exist (fullfile(testPath,
                                                               'loadcase.m'),
                                                      'file') ||
          ... exist(fullfile(testPath, 'lib', 'loadcase.m'),
                    'file') matpowerPath = testPath;
    break;
    end end end

        if ~isempty(matpowerPath)
            fprintf('✓ Found MATPOWER at: %s\n', matpowerPath);
    addpath(genpath(matpowerPath));
    fprintf('✓ Added to MATLAB path\n');

        % Save path for future sessions
        try
            savepath;
        fprintf('✓ Path saved permanently\n');
        catch fprintf(
            '⚠ Could not save path permanently. Add manually to startup.m\n');
        end

        verifyInstallation();
        return;
        end

            % % Step 3 : Installation instructions fprintf('\n');
        fprintf('==========================================================\n');
        fprintf('   MATPOWER NOT FOUND - INSTALLATION REQUIRED\n');
        fprintf('==========================================================\n');
        fprintf('\n');
        fprintf('Please follow these steps to install MATPOWER:\n\n');

        fprintf('OPTION A: Download from Website (Recommended)\n');
        fprintf('-------------------------------------------\n');
        fprintf('1. Go to: https://matpower.org/\n');
        fprintf('2. Click "Download" and get the latest version\n');
        fprintf('3. Extract the ZIP file to a permanent location, e.g.:\n');
        fprintf('   - Mac/Linux: ~/Documents/MATLAB/matpower\n');
        fprintf('   - Windows: C:\\MATLAB\\matpower\n');
        fprintf('4. Run this in MATLAB:\n');
        fprintf('   >> addpath(genpath(' '/path/to/matpower' '))\n');
        fprintf('   >> savepath\n');
        fprintf('5. Re-run this script to verify\n');
        fprintf('\n');

        fprintf('OPTION B: Clone from GitHub\n');
        fprintf('---------------------------\n');
        fprintf('1. Open Terminal/Command Prompt\n');
        fprintf('2. Run:\n');
        fprintf('   git clone https://github.com/MATPOWER/matpower.git\n');
        fprintf('3. In MATLAB:\n');
        fprintf('   >> addpath(genpath(' '/path/to/matpower' '))\n');
        fprintf('   >> install_matpower\n');
        fprintf('\n');

        fprintf('After installation, run this script again:\n');
        fprintf('   >> setupMatpower\n');
        fprintf('\n');

        fprintf('Or specify the path directly:\n');
        fprintf('   >> setupMatpower(' '/your/matpower/path' ')\n');
        fprintf('\n');
        end

            % %
            Verify MATPOWER installation function verifyInstallation()
                fprintf('\n');
        fprintf('Step 3: Verifying MATPOWER installation...\n');

        allGood = true;

        % Test 1
            : Load a test case fprintf('  [1/4] Loading IEEE 14-bus case... ');
            try mpc = loadcase('case14'); fprintf('✓\n');
            catch ME fprintf('✗ (%s)\n', ME.message); allGood = false; end

                                                                       % Test 2:
        Run power flow fprintf('  [2/4] Running power flow... ');
        try mpopt = mpoption('verbose', 0, 'out.all', 0);
        results = runpf(mpc, mpopt);
        if results
          .success fprintf('✓\n');
        else
          fprintf('✗ (power flow did not converge)\n');
        allGood = false;
        end catch ME fprintf('✗ (%s)\n', ME.message);
        allGood = false;
        end

            % Test 3 : Make Ybus matrix
                           fprintf('  [3/4] Computing admittance matrix... ');
        try[Ybus, ~, ~] = makeYbus(mpc);
        fprintf('✓\n');
        catch ME fprintf('✗ (%s)\n', ME.message);
        allGood = false;
        end

            % Test 4 : Check available test cases
                           fprintf('  [4/4] Checking available test cases... ');
        testCases = {'case9', 'case14', 'case30', 'case57', 'case118'};
        availableCases = {};
    for
      i = 1 : length(testCases) if exist (testCases{i}, 'file')
                  availableCases{end + 1} = testCases{i};
    end end fprintf('✓ (%d cases available)\n', length(availableCases));

    % Summary fprintf('\n');
    if allGood
      fprintf('==========================================================\n');
    fprintf('   ✓ MATPOWER INSTALLATION VERIFIED SUCCESSFULLY!\n');
    fprintf('==========================================================\n');
    fprintf('\n');
    fprintf('Available IEEE bus systems:\n');
        for
          i = 1 : length(availableCases) fprintf('  - %s\n', availableCases{i});
        end fprintf('\n');
        fprintf('You can now run the FDIA detection system:\n');
        fprintf('  >> main\n');
        fprintf('\n');
        else fprintf(
            '==========================================================\n');
        fprintf('   ⚠ MATPOWER INSTALLATION HAS ISSUES\n');
        fprintf('==========================================================\n');
        fprintf('\n');
        fprintf('Please check the errors above and reinstall MATPOWER.\n');
        fprintf('\n');
        end end
