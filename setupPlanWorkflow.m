function setupPlanWorkflow(matRadRoot)
% setupPlanWorkflow Add planWorkflow and, optionally, matRad to the MATLAB path.
%
% call:
%   setupPlanWorkflow
%   setupPlanWorkflow(matRadRoot)

if nargin < 1
    matRadRoot = '';
end

planWorkflowRoot = fileparts(mfilename('fullpath'));
addPathIfMissing(planWorkflowRoot);

if ~isempty(matRadRoot)
    matRadRoot = char(matRadRoot);
    matRadRc = fullfile(matRadRoot,'matRad_rc.m');
    if ~isfile(matRadRc)
        error('planWorkflow:setup:MatRadNotFound', ...
            'Could not find matRad_rc.m in %s.',matRadRoot);
    end
    addPathIfMissing(matRadRoot);
end

if exist('matRad_rc','file') == 2
    matRad_rc(false);
end

end

function addPathIfMissing(folderPath)

folderPath = char(folderPath);
pathEntries = strsplit(path,pathsep);
if ~any(strcmp(pathEntries,folderPath))
    addpath(folderPath);
end

end
