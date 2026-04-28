function results = runTests(pathToMatRadRoot)
% runTests Run the robOpt MATLAB unit tests.

if nargin < 1
    pathToMatRadRoot = '';
end

robOptFolder = fileparts(mfilename('fullpath'));
testFolder = fullfile(robOptFolder,'tests');

initializeMatRad(robOptFolder,pathToMatRadRoot);
if ~any(strcmp(strsplit(path,pathsep),testFolder))
    addpath(testFolder);
    cleanupObj = onCleanup(@() rmpath(testFolder));
end

suite = matlab.unittest.TestSuite.fromFolder(testFolder);
if isempty(suite)
    error('robOpt:runTests:EmptySuite', ...
        'No robOpt tests were discovered in %s.',testFolder);
end
runner = matlab.unittest.TestRunner.withTextOutput( ...
    'Verbosity',matlab.unittest.Verbosity.Detailed);
results = runner.run(suite);

if nargout == 0 && ~all([results.Passed])
    error('robOpt:runTests:Failed', ...
        '%d robOpt test(s) did not pass.',sum(~[results.Passed]));
end

end

function initializeMatRad(robOptFolder,pathToMatRadRoot)

if exist('matRad_getDisplayDoseScale','file') == 2 && ...
        exist('MatRad_Config','class') == 8
    return;
end

packagesFolder = fileparts(robOptFolder);
userDataRoot = fileparts(packagesFolder);
candidateMatRadRoot = regexprep(userDataRoot,'_userdata$','');

if ~isempty(pathToMatRadRoot)
    candidateMatRadRoot = char(pathToMatRadRoot);
end

if isfile(fullfile(candidateMatRadRoot,'matRad_rc.m'))
    addpath(candidateMatRadRoot);
    matRad_rc(false);
elseif exist('matRad_rc','file') == 2
    matRad_rc(false);
else
    error('robOpt:runTests:MatRadNotFound', ...
        ['Could not initialize matRad. Add the matRad root folder to the ' ...
         'MATLAB path before running robOpt.runTests().']);
end

end
