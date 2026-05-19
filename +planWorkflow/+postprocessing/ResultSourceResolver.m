classdef ResultSourceResolver
    % ResultSourceResolver Finds workflow_results.mat files for postprocessing.

    methods (Static)
        function files = discover(paths)
            paths = planWorkflow.postprocessing.ResultSourceResolver.asCellstr(paths);
            files = {};
            for i = 1:numel(paths)
                currentPath = char(paths{i});
                if isempty(currentPath)
                    continue;
                end
                if isfile(currentPath)
                    [~,name,ext] = fileparts(currentPath);
                    if strcmp([name ext],'workflow_results.mat')
                        files{end + 1} = ...
                            planWorkflow.postprocessing.ResultSourceResolver.absolutePath(currentPath); %#ok<AGROW>
                    end
                    continue;
                end
                if ~isfolder(currentPath)
                    error('planWorkflow:postprocessing:ResultSourceResolver:MissingPath', ...
                        'Postprocessing input path does not exist: %s',currentPath);
                end
                files = [files ...
                    planWorkflow.postprocessing.ResultSourceResolver.discoverFolder(currentPath)]; %#ok<AGROW>
            end
            files = planWorkflow.postprocessing.ResultSourceResolver.uniquePaths(files);
        end

        function rows = tableRows(files)
            files = planWorkflow.postprocessing.ResultSourceResolver.asCellstr(files);
            rows = cell(numel(files),3);
            for i = 1:numel(files)
                [folder,name,ext] = fileparts(files{i});
                rows(i,:) = {sprintf('%d',i),folder,[name ext]};
            end
        end
    end

    methods (Static, Access = private)
        function files = discoverFolder(folder)
            folder = ...
                planWorkflow.postprocessing.ResultSourceResolver.absolutePath(folder);
            files = {};
            directResult = fullfile(folder,'workflow_results.mat');
            if isfile(directResult)
                files{end + 1} = ...
                    planWorkflow.postprocessing.ResultSourceResolver.absolutePath(directResult);
            end

            entries = dir(folder);
            for i = 1:numel(entries)
                entry = entries(i);
                if ~entry.isdir || strcmp(entry.name,'.') || strcmp(entry.name,'..')
                    continue;
                end
                childFolder = fullfile(folder,entry.name);
                files = [files ...
                    planWorkflow.postprocessing.ResultSourceResolver.discoverFolder(childFolder)]; %#ok<AGROW>
            end
        end

        function paths = asCellstr(paths)
            if nargin < 1 || isempty(paths)
                paths = {};
            elseif ischar(paths)
                paths = {paths};
            elseif isstring(paths)
                paths = cellstr(paths);
            end
        end

        function paths = uniquePaths(paths)
            result = {};
            seen = containers.Map('KeyType','char','ValueType','logical');
            for i = 1:numel(paths)
                path = char(paths{i});
                key = path;
                if ispc
                    key = lower(key);
                end
                if ~isKey(seen,key)
                    seen(key) = true;
                    result{end + 1} = path; %#ok<AGROW>
                end
            end
            paths = result;
        end

        function path = absolutePath(path)
            path = char(path);
            try
                fileObj = java.io.File(path);
                path = char(fileObj.getCanonicalPath());
            catch
                if isfolder(path)
                    currentFolder = pwd;
                    cleanupObj = onCleanup(@() cd(currentFolder));
                    cd(path);
                    path = pwd;
                    clear cleanupObj;
                else
                    [folder,name,ext] = fileparts(path);
                    folder = ...
                        planWorkflow.postprocessing.ResultSourceResolver.absolutePath(folder);
                    path = fullfile(folder,[name ext]);
                end
            end
        end
    end
end
