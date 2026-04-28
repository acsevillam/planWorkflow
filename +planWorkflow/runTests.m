function results = runTests(pathToMatRadRoot)
% runTests Run the planWorkflow MATLAB unit tests.

if nargin < 1
    pathToMatRadRoot = '';
end

planWorkflowFolder = fileparts(mfilename('fullpath'));
testFolder = fullfile(planWorkflowFolder,'tests');

initializeMatRad(planWorkflowFolder,pathToMatRadRoot);
if ~any(strcmp(strsplit(path,pathsep),testFolder))
    addpath(testFolder);
    cleanupObj = onCleanup(@() rmpath(testFolder));
end

suite = matlab.unittest.TestSuite.fromFolder(testFolder);
if isempty(suite)
    error('planWorkflow:runTests:EmptySuite', ...
        'No planWorkflow tests were discovered in %s.',testFolder);
end
runner = matlab.unittest.TestRunner.withTextOutput( ...
    'Verbosity',matlab.unittest.Verbosity.Detailed);
results = runner.run(suite);

if nargout == 0 && ~all([results.Passed])
    error('planWorkflow:runTests:Failed', ...
        '%d planWorkflow test(s) did not pass.',sum(~[results.Passed]));
end

end

function initializeMatRad(planWorkflowFolder,pathToMatRadRoot)

if exist('matRad_getDisplayDoseScale','file') == 2 && ...
        exist('MatRad_Config','class') == 8
    return;
end

packagesFolder = fileparts(planWorkflowFolder);
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
    error('planWorkflow:runTests:MatRadNotFound', ...
        ['Could not initialize matRad. Add the matRad root folder to the ' ...
         'MATLAB path before running planWorkflow.runTests().']);
end

end
