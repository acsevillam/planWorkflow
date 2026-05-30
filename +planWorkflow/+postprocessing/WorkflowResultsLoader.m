classdef WorkflowResultsLoader
    % WorkflowResultsLoader Loads compact native workflow results snapshots.

    methods (Static)
        function items = loadAll(files)
            files = planWorkflow.postprocessing.WorkflowResultsLoader.asCellstr( ...
                files);
            items = planWorkflow.postprocessing.WorkflowResultsLoader.emptyItems();
            for i = 1:numel(files)
                items(end + 1) = ... %#ok<AGROW>
                    planWorkflow.postprocessing.WorkflowResultsLoader.load( ...
                    files{i});
            end
        end

        function item = load(filePath)
            filePath = ...
                planWorkflow.postprocessing.WorkflowResultsLoader.absolutePath( ...
                filePath);
            if ~isfile(filePath)
                error('planWorkflow:postprocessing:WorkflowResultsLoader:MissingFile', ...
                    'Workflow results file does not exist: %s',filePath);
            end

            snapshot = load(filePath,'results','resultsMetadata');
            if ~isfield(snapshot,'results') || ~isstruct(snapshot.results)
                error('planWorkflow:postprocessing:WorkflowResultsLoader:MissingResults', ...
                    'File does not contain a results struct: %s',filePath);
            end

            results = snapshot.results;
            if isfield(results,'sampling')
                results.sampling = ...
                    planWorkflow.resources.StageDataLifecycle.compactSamplingResults( ...
                    results.sampling);
            end
            results = ...
                planWorkflow.postprocessing.WorkflowResultsLoader.resolveFigureFiles( ...
                results,fileparts(filePath));

            metadata = struct();
            if isfield(snapshot,'resultsMetadata')
                metadata = snapshot.resultsMetadata;
            end

            item = struct( ...
                'sourceFile',filePath, ...
                'label', ...
                planWorkflow.postprocessing.WorkflowResultsLoader.resultLabel( ...
                filePath,results,metadata), ...
                'results',results);
        end

        function items = emptyItems()
            template = struct('sourceFile','','label','','results',struct());
            items = template([]);
        end
    end

    methods (Static, Access = private)
        function files = asCellstr(files)
            if nargin < 1 || isempty(files)
                files = {};
            elseif ischar(files)
                files = {files};
            elseif isstring(files)
                files = cellstr(files);
            end
        end

        function label = resultLabel(filePath,results,metadata)
            label = '';
            if isstruct(results) && isfield(results,'runConfig') && ...
                    isstruct(results.runConfig) && ...
                    isfield(results.runConfig,'runId')
                label = ...
                    planWorkflow.postprocessing.WorkflowResultsLoader.labelText( ...
                    results.runConfig.runId);
            end
            if isempty(label) && isstruct(metadata) && ...
                    isfield(metadata,'runId')
                label = ...
                    planWorkflow.postprocessing.WorkflowResultsLoader.labelText( ...
                    metadata.runId);
            end
            if isempty(label)
                parentFolder = fileparts(filePath);
                [~,label] = fileparts(parentFolder);
            end
            if isempty(label)
                label = 'workflow_results';
            end
        end

        function text = labelText(value)
            text = '';
            if ischar(value)
                text = strtrim(value);
            elseif isstring(value) && isscalar(value)
                text = strtrim(char(value));
            elseif isnumeric(value) && isscalar(value)
                text = strtrim(num2str(value));
            end
        end

        function results = resolveFigureFiles(results,rootFolder)
            if ~isstruct(results)
                return;
            end

            if isfield(results,'geometry')
                results.geometry = ...
                    planWorkflow.postprocessing.WorkflowResultsLoader.resolvePlanFigureFiles( ...
                    results.geometry,rootFolder);
            end
            if isfield(results,'reference')
                results.reference = ...
                    planWorkflow.postprocessing.WorkflowResultsLoader.resolvePlanFigureFiles( ...
                    results.reference,rootFolder);
            end
            if isfield(results,'robust')
                results.robust = ...
                    planWorkflow.postprocessing.WorkflowResultsLoader.resolvePlanCollectionFigureFiles( ...
                    results.robust,rootFolder);
            end
            if isfield(results,'sampling') && isstruct(results.sampling)
                results.sampling = ...
                    planWorkflow.postprocessing.WorkflowResultsLoader.resolveSamplingFigureFiles( ...
                    results.sampling,rootFolder);
            end
        end

        function sampling = resolveSamplingFigureFiles(sampling,rootFolder)
            if isfield(sampling,'reference')
                sampling.reference = ...
                    planWorkflow.postprocessing.WorkflowResultsLoader.resolvePlanFigureFiles( ...
                    sampling.reference,rootFolder);
            end
            if isfield(sampling,'robust')
                sampling.robust = ...
                    planWorkflow.postprocessing.WorkflowResultsLoader.resolvePlanCollectionFigureFiles( ...
                    sampling.robust,rootFolder);
            end
        end

        function plans = resolvePlanCollectionFigureFiles(plans,rootFolder)
            if iscell(plans)
                for i = 1:numel(plans)
                    plans{i} = ...
                        planWorkflow.postprocessing.WorkflowResultsLoader.resolvePlanFigureFiles( ...
                        plans{i},rootFolder);
                end
            elseif isstruct(plans)
                for i = 1:numel(plans)
                    plans(i) = ...
                        planWorkflow.postprocessing.WorkflowResultsLoader.resolvePlanFigureFiles( ...
                        plans(i),rootFolder);
                end
            end
        end

        function planResults = resolvePlanFigureFiles(planResults,rootFolder)
            if ~isstruct(planResults) || ...
                    ~isfield(planResults,'figureFiles') || ...
                    ~isstruct(planResults.figureFiles)
                return;
            end

            figureFields = fieldnames(planResults.figureFiles);
            for fieldIx = 1:numel(figureFields)
                fieldName = figureFields{fieldIx};
                planResults.figureFiles.(fieldName) = ...
                    planWorkflow.postprocessing.WorkflowResultsLoader.resolveFigurePath( ...
                    planResults.figureFiles.(fieldName),rootFolder);
            end
        end

        function filePath = resolveFigurePath(filePath,rootFolder)
            if isstring(filePath) && isscalar(filePath)
                filePath = char(filePath);
            end
            if ~ischar(filePath) || isempty(filePath) || isfile(filePath)
                return;
            end

            [~,name,ext] = fileparts(filePath);
            if isempty(name) || isempty(ext)
                return;
            end

            localPath = ...
                planWorkflow.postprocessing.WorkflowResultsLoader.findLocalFigureFile( ...
                rootFolder,[name ext]);
            if ~isempty(localPath)
                filePath = localPath;
            end
        end

        function filePath = findLocalFigureFile(rootFolder,fileName)
            filePath = '';
            if isempty(rootFolder) || ~isfolder(rootFolder)
                return;
            end

            candidates = { ...
                fullfile(rootFolder,'sampling_analysis',fileName), ...
                fullfile(rootFolder,'geometry',fileName), ...
                fullfile(rootFolder,fileName)};
            for i = 1:numel(candidates)
                if isfile(candidates{i})
                    filePath = candidates{i};
                    return;
                end
            end

            matches = dir(fullfile(rootFolder,'**',fileName));
            for i = 1:numel(matches)
                if ~matches(i).isdir
                    filePath = fullfile(matches(i).folder,matches(i).name);
                    return;
                end
            end
        end

        function path = absolutePath(path)
            path = char(path);
            try
                path = char(java.io.File(path).getCanonicalPath());
            catch
                if isfolder(path)
                    currentFolder = pwd;
                    cleanupObj = onCleanup(@() cd(currentFolder));
                    cd(path);
                    path = pwd;
                    clear cleanupObj;
                else
                    [folder,name,ext] = fileparts(path);
                    if ~isempty(folder)
                        folder = ...
                            planWorkflow.postprocessing.WorkflowResultsLoader.absolutePath( ...
                            folder);
                    end
                    path = fullfile(folder,[name ext]);
                end
            end
        end
    end
end
