function setupRobOpt(matRadRoot)
% setupRobOpt Add robOpt and, optionally, matRad to the MATLAB path.
%
% call:
%   setupRobOpt
%   setupRobOpt(matRadRoot)

if nargin < 1
    matRadRoot = '';
end

robOptRoot = fileparts(mfilename('fullpath'));
addPathIfMissing(robOptRoot);

if ~isempty(matRadRoot)
    matRadRoot = char(matRadRoot);
    matRadRc = fullfile(matRadRoot,'matRad_rc.m');
    if ~isfile(matRadRc)
        error('robOpt:setup:MatRadNotFound', ...
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
