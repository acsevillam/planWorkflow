classdef PostprocessingEditor
    % PostprocessingEditor Interactive MATLAB GUI for Python postprocessing.

    methods (Static)
        function frame = open(options)
            if nargin < 1
                options = struct();
            end
            options = planWorkflow.gui.PostprocessingEditor.normalizeOptions(options);
            if ~usejava('desktop')
                error('planWorkflow:gui:PostprocessingEditor:Unavailable', ...
                    'The postprocessing editor requires MATLAB GUI support.');
            end

            state = struct();
            state.sources = {};
            state.selectedSourceRows = [];
            state.selectedFilterRows = [];
            state.resultEntries = ...
                planWorkflow.postprocessing.GeneratedFileIndex.pngEntries('');
            state.running = false;

            callbacks = struct( ...
                'addFolder',@addFolderCallback, ...
                'removeSources',@removeSourcesCallback, ...
                'clearSources',@clearSourcesCallback, ...
                'sourceSelected',@sourceSelectedCallback, ...
                'addFilter',@addFilterCallback, ...
                'removeFilter',@removeFilterCallback, ...
                'filterSelected',@filterSelectedCallback, ...
                'browsePythonExecutable',@browsePythonExecutableCallback, ...
                'browsePythonPath',@browsePythonPathCallback, ...
                'browseOutput',@browseOutputCallback, ...
                'selectionChanged',@selectionChangedCallback, ...
                'openOutputFolder',@openOutputFolderCallback, ...
                'openOutputFolderPath',@openOutputFolderCallback, ...
                'openResultFile',@openResultFileCallback, ...
                'run',@runCallback, ...
                'close',@closeCallback);

            frame = planWorkflow.gui.PostprocessingEditorFrame.create( ...
                options,callbacks);
            set(frame.pythonEdit,'String',options.pythonExecutable);
            set(frame.pythonPathEdit,'String',options.pythonPath);
            set(frame.outputDirEdit,'String',options.outputDir);
            if ~isempty(options.initialFolders)
                addSourcesFromPaths(options.initialFolders);
            else
                refreshSourceTable();
                refreshCommandPreview();
            end

            function addFolderCallback(~,~)
                folder = uigetdir(pwd,'Add postprocessing result folder');
                if isequal(folder,0)
                    return;
                end
                addSourcesFromPaths({folder});
            end

            function addSourcesFromPaths(paths)
                try
                    discovered = ...
                        planWorkflow.postprocessing.ResultSourceResolver.discover(paths);
                    if isempty(discovered)
                        errordlg('No workflow_results.mat files were found.', ...
                            'Add result folder');
                        return;
                    end
                    state.sources = uniquePaths([state.sources discovered]);
                    refreshSourceTable();
                    refreshCommandPreview();
                catch ME
                    errordlg(ME.message,'Add result folder');
                end
            end

            function removeSourcesCallback(~,~)
                rows = state.selectedSourceRows;
                if isempty(rows)
                    return;
                end
                keep = true(1,numel(state.sources));
                rows = rows(rows >= 1 & rows <= numel(keep));
                keep(rows) = false;
                state.sources = state.sources(keep);
                state.selectedSourceRows = [];
                refreshSourceTable();
                refreshCommandPreview();
            end

            function clearSourcesCallback(~,~)
                state.sources = {};
                state.selectedSourceRows = [];
                refreshSourceTable();
                refreshCommandPreview();
            end

            function sourceSelectedCallback(~,event)
                state.selectedSourceRows = selectedRows(event);
            end

            function addFilterCallback(~,~)
                data = get(frame.filterTable,'Data');
                data(end + 1,:) = {'include','',''};
                set(frame.filterTable,'Data',data);
                refreshCommandPreview();
            end

            function removeFilterCallback(~,~)
                data = get(frame.filterTable,'Data');
                rows = state.selectedFilterRows;
                if isempty(rows) || isempty(data)
                    return;
                end
                keep = true(1,size(data,1));
                rows = rows(rows >= 1 & rows <= numel(keep));
                keep(rows) = false;
                data = data(keep,:);
                state.selectedFilterRows = [];
                set(frame.filterTable,'Data',data);
                refreshCommandPreview();
            end

            function filterSelectedCallback(~,event)
                state.selectedFilterRows = selectedRows(event);
            end

            function browsePythonExecutableCallback(~,~)
                currentExecutable = char(get(frame.pythonEdit,'String'));
                currentFolder = pwd;
                if isfile(currentExecutable)
                    currentFolder = fileparts(currentExecutable);
                elseif isfolder(currentExecutable)
                    currentFolder = currentExecutable;
                end
                [fileName,folder] = uigetfile({'*','All files'}, ...
                    'Select Python executable',currentFolder);
                if isequal(fileName,0) || isequal(folder,0)
                    return;
                end
                set(frame.pythonEdit,'String',fullfile(folder,fileName));
                refreshCommandPreview();
            end

            function browsePythonPathCallback(~,~)
                currentPath = firstPythonPathEntry( ...
                    char(get(frame.pythonPathEdit,'String')));
                if isempty(currentPath) || ~isfolder(currentPath)
                    currentPath = pwd;
                end
                folder = uigetdir(currentPath,'Select Python path folder');
                if isequal(folder,0)
                    return;
                end
                set(frame.pythonPathEdit,'String',folder);
                refreshCommandPreview();
            end

            function browseOutputCallback(~,~)
                currentFolder = char(get(frame.outputDirEdit,'String'));
                if isempty(currentFolder) || ~isfolder(currentFolder)
                    currentFolder = pwd;
                end
                folder = uigetdir(currentFolder,'Select postprocessing output directory');
                if isequal(folder,0)
                    return;
                end
                set(frame.outputDirEdit,'String',folder);
                refreshCommandPreview();
            end

            function selectionChangedCallback(~,~)
                refreshCommandPreview();
            end

            function runCallback(~,~)
                if state.running
                    return;
                end
                try
                    config = currentConfig();
                    commands = ...
                        planWorkflow.postprocessing.CliCommandBuilder.buildCommands(config);
                    outputDir = char(config.outputDir);
                    if ~isfolder(outputDir)
                        mkdir(outputDir);
                    end
                catch ME
                    errordlg(ME.message,'Run postprocessing');
                    return;
                end

                previousEntries = state.resultEntries;
                state.running = true;
                set(frame.runButton,'Enable','off');
                cleanupObj = onCleanup(@() finishRunUi());
                frame.progressReporter.log('Starting postprocessing.');
                frame.progressReporter.setProgress(0,'Postprocessing running.');
                try
                    for i = 1:numel(commands)
                        frame.progressReporter.setProgress((i - 1) / numel(commands), ...
                            sprintf('Running postprocessing command %d/%d.', ...
                            i,numel(commands)));
                        frame.progressReporter.log(sprintf( ...
                            'Running command %d/%d.',i,numel(commands)));
                        [status,output] = system(commands{i});
                        logCommandOutput(output);
                        if status ~= 0
                            error('planWorkflow:gui:PostprocessingEditor:CommandFailed', ...
                                'Postprocessing command %d failed with status %d.', ...
                                i,status);
                        end
                    end
                    entries = ...
                        planWorkflow.postprocessing.GeneratedFileIndex.pngEntries(outputDir);
                    if isempty(entries)
                        error('planWorkflow:gui:PostprocessingEditor:NoGeneratedFigures', ...
                            'No PNG figures were generated in %s.',outputDir);
                    end
                    state.resultEntries = entries;
                    frame = ...
                        planWorkflow.gui.PostprocessingEditorFrame.showResultsTab( ...
                        frame,outputDir,state.resultEntries,callbacks);
                    frame.progressReporter.setProgress(1,'Postprocessing completed.');
                    frame.progressReporter.log('Postprocessing completed.');
                catch ME
                    state.resultEntries = previousEntries;
                    frame.progressReporter.log(ME.message);
                    errordlg(ME.message,'Run postprocessing');
                end
                clear cleanupObj;
            end

            function finishRunUi()
                state.running = false;
                if ishandle(frame.runButton)
                    set(frame.runButton,'Enable','on');
                end
            end

            function openResultFileCallback(~,~,filePath)
                try
                    planWorkflow.postprocessing.PngViewer.open( ...
                        filePath);
                catch ME
                    errordlg(ME.message,'Open figure');
                end
            end

            function openOutputFolderCallback(~,~,folderPath)
                if nargin < 3 || isempty(folderPath)
                    folderPath = char(get(frame.outputDirEdit,'String'));
                end
                openOutputFolder(folderPath);
            end

            function closeCallback(~,~)
                if ishandle(frame.fig)
                    delete(frame.fig);
                end
            end

            function config = currentConfig()
                config = planWorkflow.postprocessing.CliCommandBuilder.defaultConfig();
                config.pythonExecutable = char(get(frame.pythonEdit,'String'));
                config.pythonPath = char(get(frame.pythonPathEdit,'String'));
                config.matFiles = state.sources;
                config.outputDir = char(get(frame.outputDirEdit,'String'));
                config.endpointEnabled = logical(get(frame.endpointCheckbox,'Value'));
                config.endpointStat = popupValue(frame.endpointStatPopup);
                config.endpointFilter = popupValue(frame.endpointFilterPopup);
                precomputeTime = logical(get(frame.precomputeTimeCheckbox,'Value'));
                optimizationRtpi = logical(get(frame.optimizationRtpiCheckbox,'Value'));
                config.timeEnabled = precomputeTime || optimizationRtpi;
                config.timeMode = selectedTimeMode(precomputeTime,optimizationRtpi);
                config.timeValue = popupValue(frame.timeValuePopup);
                config.dijEnabled = logical(get(frame.precomputeSizeCheckbox,'Value'));
                config.sizeValue = popupValue(frame.sizeValuePopup);
                config.filters = ...
                    planWorkflow.postprocessing.CliCommandBuilder.filtersFromTableRows( ...
                    get(frame.filterTable,'Data'));
            end

            function refreshSourceTable()
                set(frame.sourceTable,'Data', ...
                    planWorkflow.postprocessing.ResultSourceResolver.tableRows( ...
                    state.sources));
            end

            function refreshCommandPreview()
                try
                    config = currentConfig();
                    commands = ...
                        planWorkflow.postprocessing.CliCommandBuilder.buildCommands(config);
                    set(frame.commandPreview,'String',commands,'Value',1);
                catch ME
                    set(frame.commandPreview,'String',{ME.message},'Value',1);
                end
            end

            function logCommandOutput(output)
                if isempty(output)
                    return;
                end
                lines = regexp(output,'\r\n|\n|\r','split');
                for lineIx = 1:numel(lines)
                    line = strtrim(lines{lineIx});
                    if ~isempty(line)
                        frame.progressReporter.log(line);
                    end
                end
            end
        end
    end

    methods (Static, Access = private)
        function options = normalizeOptions(options)
            defaults = planWorkflow.postprocessing.CliCommandBuilder.defaultConfig();
            if ~isfield(options,'pythonExecutable') || ...
                    isempty(options.pythonExecutable)
                options.pythonExecutable = defaults.pythonExecutable;
            end
            if ~isfield(options,'pythonPath') || isempty(options.pythonPath)
                options.pythonPath = defaults.pythonPath;
            end
            if ~isfield(options,'outputDir') || isempty(options.outputDir)
                options.outputDir = defaults.outputDir;
            end
            if ~isfield(options,'initialFolders') || isempty(options.initialFolders)
                options.initialFolders = {};
            elseif ischar(options.initialFolders)
                options.initialFolders = {options.initialFolders};
            elseif isstring(options.initialFolders)
                options.initialFolders = cellstr(options.initialFolders);
            end
        end
    end
end

function rows = selectedRows(event)
rows = [];
if isempty(event.Indices)
    return;
end
rows = unique(event.Indices(:,1))';
end

function value = popupValue(handle)
values = get(handle,'String');
index = get(handle,'Value');
if iscell(values)
    value = values{index};
else
    value = strtrim(values(index,:));
end
value = char(value);
end

function mode = selectedTimeMode(precomputeTime,optimizationRtpi)
if precomputeTime && optimizationRtpi
    mode = 'all';
elseif precomputeTime
    mode = 'precompute_dij_time';
elseif optimizationRtpi
    mode = 'optimization_rtpi';
else
    mode = 'all';
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

function openOutputFolder(folderPath)
folderPath = char(folderPath);
if isempty(folderPath) || ~isfolder(folderPath)
    errordlg(sprintf('Could not open folder "%s".',folderPath), ...
        'Open output folder');
    return;
end
try
    if ispc
        winopen(folderPath);
    elseif ismac
        system(['open ' ...
            planWorkflow.postprocessing.CliCommandBuilder.shellQuote(folderPath)]);
    else
        system(['xdg-open ' ...
            planWorkflow.postprocessing.CliCommandBuilder.shellQuote(folderPath) ...
            ' &']);
    end
catch ME
    errordlg(sprintf('Could not open folder "%s": %s', ...
        folderPath,ME.message),'Open output folder');
end
end

function entry = firstPythonPathEntry(pythonPath)
entries = strsplit(char(pythonPath),pathsep);
entry = '';
for i = 1:numel(entries)
    candidate = strtrim(entries{i});
    if ~isempty(candidate)
        entry = candidate;
        return;
    end
end
end
