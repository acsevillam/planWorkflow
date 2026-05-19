classdef MacroRunner
    % MacroRunner Interactive GUI for selecting and running workflow macros.

    methods (Static)
        function frame = open(options)
            if nargin < 1
                options = struct();
            end
            options = planWorkflow.gui.MacroRunner.normalizeOptions(options);
            if ~usejava('desktop')
                error('planWorkflow:gui:MacroRunner:Unavailable', ...
                    'The macro runner requires MATLAB GUI support.');
            end

            state = struct();
            state.entries = ...
                planWorkflow.macros.MacroFileResolver.discover({});
            state.visibleEntries = state.entries;
            state.selectedRow = [];
            state.selectedMetadata = [];
            state.running = false;

            callbacks = struct( ...
                'browseFolder',@browseFolderCallback, ...
                'folderChanged',@folderChangedCallback, ...
                'refresh',@refreshCallback, ...
                'selectFile',@selectFileCallback, ...
                'searchChanged',@searchChangedCallback, ...
                'clearSearch',@clearSearchCallback, ...
                'macroSelected',@macroSelectedCallback, ...
                'optionsChanged',@optionsChangedCallback, ...
                'browseRootPath',@browseRootPathCallback, ...
                'browseCacheRootPath',@browseCacheRootPathCallback, ...
                'openFolder',@openFolderCallback, ...
                'validate',@validateCallback, ...
                'run',@runCallback, ...
                'close',@closeCallback);

            frame = planWorkflow.gui.MacroRunnerFrame.create( ...
                options,callbacks);
            set(frame.folderEdit,'String',options.macroFolder);
            refreshMacroList(false);
            frame.progressReporter.setProgress(0,'Ready to run macro.');

            function browseFolderCallback(~,~)
                currentFolder = char(get(frame.folderEdit,'String'));
                if isempty(currentFolder) || ~isfolder(currentFolder)
                    currentFolder = pwd;
                end
                folder = uigetdir(currentFolder,'Select macro folder');
                if isequal(folder,0)
                    return;
                end
                set(frame.folderEdit,'String',folder);
                refreshMacroList(true);
            end

            function folderChangedCallback(~,~)
                refreshMacroList(false);
            end

            function refreshCallback(~,~)
                refreshMacroList(true);
            end

            function selectFileCallback(~,~)
                currentFolder = char(get(frame.folderEdit,'String'));
                if isempty(currentFolder) || ~isfolder(currentFolder)
                    currentFolder = pwd;
                end
                [fileName,folder] = uigetfile({'*.m','MATLAB macros (*.m)'}, ...
                    'Select workflow macro',currentFolder);
                if isequal(fileName,0) || isequal(folder,0)
                    return;
                end
                filePath = fullfile(folder,fileName);
                selectMacroFile(filePath);
            end

            function macroSelectedCallback(~,event)
                rows = selectedRows(event);
                if isempty(rows)
                    return;
                end
                row = rows(1);
                if row < 1 || row > numel(state.visibleEntries)
                    return;
                end
                state.selectedRow = row;
                loadMacroMetadata(state.visibleEntries(row).filePath);
            end

            function searchChangedCallback(~,~)
                applyMacroFilter(true);
            end

            function clearSearchCallback(~,~)
                set(frame.searchEdit,'String','');
                applyMacroFilter(true);
            end

            function optionsChangedCallback(~,~)
                frame = planWorkflow.gui.MacroRunnerFrame.deleteResultsTab( ...
                    frame);
            end

            function browseRootPathCallback(~,~)
                browsePathInto(frame.rootPathEdit,'Select macro root path');
            end

            function browseCacheRootPathCallback(~,~)
                browsePathInto(frame.cacheRootPathEdit, ...
                    'Select macro cache root path');
            end

            function openFolderCallback(~,~)
                openFolder(char(get(frame.folderEdit,'String')));
            end

            function validateCallback(~,~)
                try
                    metadata = selectedMetadata();
                    planWorkflow.macros.MacroFileResolver.validate( ...
                        metadata.filePath);
                    rows = [ ...
                        {'Status','Valid'}; ...
                        planWorkflow.macros.MacroFileResolver.summaryRows( ...
                        metadata)];
                    frame = planWorkflow.gui.MacroRunnerFrame.showResultsTab( ...
                        frame,'Validation',rows);
                    frame.progressReporter.log(sprintf( ...
                        'Validated macro %s.',metadata.functionName));
                    frame.progressReporter.setProgress(1,'Macro validated.');
                catch ME
                    frame.progressReporter.log(ME.message);
                    errordlg(ME.message,'Validate macro');
                end
            end

            function runCallback(~,~)
                if state.running
                    return;
                end
                try
                    metadata = selectedMetadata();
                    metadata = planWorkflow.macros.MacroFileResolver.validate( ...
                        metadata.filePath);
                    executionOptions = currentExecutionOptions();
                    args = planWorkflow.macros.MacroFileResolver.executionArguments( ...
                        metadata,executionOptions);
                catch ME
                    frame.progressReporter.log(ME.message);
                    errordlg(ME.message,'Run macro');
                    return;
                end

                state.running = true;
                set(frame.runButton,'Enable','off');
                cleanupUi = onCleanup(@() finishRunUi());
                frame.progressReporter.log(sprintf( ...
                    'Running macro %s.',metadata.functionName));
                frame.progressReporter.setProgress(0,'Macro running.');

                try
                    previousPath = path;
                    addpath(metadata.folder,'-begin');
                    cleanupPath = onCleanup(@() path(previousPath));
                    output = runMacroFunction(metadata.functionName,args);
                    clear cleanupPath;

                    rows = [ ...
                        {'Status','Completed'}; ...
                        {'Function',metadata.functionName}; ...
                        {'File',metadata.filePath}; ...
                        {'Arguments',argumentText(args)}; ...
                        {'Output',outputText(output)}];
                    frame = planWorkflow.gui.MacroRunnerFrame.showResultsTab( ...
                        frame,'Run',rows);
                    frame.progressReporter.setProgress(1,'Macro completed.');
                    frame.progressReporter.log(sprintf( ...
                        'Macro %s completed.',metadata.functionName));
                catch ME
                    frame.progressReporter.log(ME.message);
                    errordlg(ME.message,'Run macro');
                end
                clear cleanupUi;
            end

            function finishRunUi()
                state.running = false;
                if ishandle(frame.runButton)
                    set(frame.runButton,'Enable','on');
                end
            end

            function closeCallback(~,~)
                if ishandle(frame.fig)
                    delete(frame.fig);
                end
            end

            function refreshMacroList(showMessages)
                folder = char(get(frame.folderEdit,'String'));
                try
                    state.entries = ...
                        planWorkflow.macros.MacroFileResolver.discover(folder);
                    applyMacroFilter(true);
                    if showMessages
                        frame.progressReporter.log(sprintf( ...
                            'Found %d macro files.',numel(state.entries)));
                    end
                catch ME
                    clearSelection();
                    frame.progressReporter.log(ME.message);
                    if showMessages
                        errordlg(ME.message,'Refresh macros');
                    end
                end
            end

            function selectMacroFile(filePath)
                try
                    entry = planWorkflow.macros.MacroFileResolver.discover( ...
                        filePath);
                    if isempty(entry)
                        error('planWorkflow:gui:MacroRunner:NoMacroFile', ...
                            'No MATLAB macro file was selected.');
                    end
                    existingPaths = {state.entries.filePath};
                    match = find(strcmp(existingPaths,entry(1).filePath),1);
                    if isempty(match)
                        state.entries = [state.entries entry(1)];
                        match = numel(state.entries);
                    end
                    set(frame.searchEdit,'String','');
                    applyMacroFilter(false);
                    state.selectedRow = match;
                    loadMacroMetadata(entry(1).filePath);
                catch ME
                    frame.progressReporter.log(ME.message);
                    errordlg(ME.message,'Select macro');
                end
            end

            function applyMacroFilter(clearCurrentSelection)
                query = char(get(frame.searchEdit,'String'));
                state.visibleEntries = ...
                    planWorkflow.macros.MacroFileResolver.filterEntries( ...
                    state.entries,query);
                set(frame.macroTable,'Data', ...
                    planWorkflow.macros.MacroFileResolver.tableRows( ...
                    state.visibleEntries, ...
                    char(get(frame.folderEdit,'String'))));
                if clearCurrentSelection
                    clearSelection();
                end
            end

            function loadMacroMetadata(filePath)
                try
                    metadata = ...
                        planWorkflow.macros.MacroFileResolver.inspect(filePath);
                    state.selectedMetadata = metadata;
                    set(frame.selectedFileEdit,'String',metadata.filePath);
                    set(frame.specTable,'Data', ...
                        planWorkflow.macros.MacroFileResolver.summaryRows( ...
                        metadata));
                    loadExecutionDefaults(metadata);
                    frame = planWorkflow.gui.MacroRunnerFrame.deleteResultsTab( ...
                        frame);
                    frame.progressReporter.log(sprintf( ...
                        'Selected macro %s.',metadata.functionName));
                catch ME
                    clearSelection();
                    frame.progressReporter.log(ME.message);
                    errordlg(ME.message,'Select macro');
                end
            end

            function loadExecutionDefaults(metadata)
                set(frame.caseIdEdit,'String',char(string( ...
                    metadata.defaults.caseID)));
                setProfilePopupValue(frame.profilePopup, ...
                    metadata.defaults.profile);
                set(frame.profilePopup,'Enable', ...
                    planWorkflow.gui.EditorChrome.enableText( ...
                    metadata.supportedOptions.profile));
                set(frame.rootPathEdit,'String',pathOptionDefault( ...
                    metadata.defaults.rootPath));
                set(frame.cacheRootPathEdit,'String',pathOptionDefault( ...
                    metadata.defaults.cacheRootPath));
                if islogical(metadata.defaults.openGui)
                    set(frame.openGuiCheckbox,'Value', ...
                        logical(metadata.defaults.openGui));
                else
                    set(frame.openGuiCheckbox,'Value',true);
                end
                set(frame.openGuiCheckbox,'Enable', ...
                    planWorkflow.gui.EditorChrome.enableText( ...
                    metadata.supportedOptions.openGui));
            end

            function metadata = selectedMetadata()
                if isempty(state.selectedMetadata)
                    error('planWorkflow:gui:MacroRunner:NoSelection', ...
                        'Select a macro before continuing.');
                end
                metadata = state.selectedMetadata;
            end

            function executionOptions = currentExecutionOptions()
                executionOptions = struct();
                executionOptions.caseID = char(get(frame.caseIdEdit,'String'));
                executionOptions.profile = popupValue(frame.profilePopup);
                executionOptions.rootPath = char(get(frame.rootPathEdit,'String'));
                executionOptions.cacheRootPath = ...
                    char(get(frame.cacheRootPathEdit,'String'));
                executionOptions.openGui = ...
                    logical(get(frame.openGuiCheckbox,'Value'));
            end

            function clearSelection()
                state.selectedRow = [];
                state.selectedMetadata = [];
                set(frame.selectedFileEdit,'String','');
                set(frame.specTable,'Data',{});
                set(frame.caseIdEdit,'String','');
                set(frame.profilePopup,'Value',1,'Enable','off');
                set(frame.rootPathEdit,'String','');
                set(frame.cacheRootPathEdit,'String','');
                set(frame.openGuiCheckbox,'Value',true,'Enable','off');
                frame = planWorkflow.gui.MacroRunnerFrame.deleteResultsTab(frame);
            end
        end
    end

    methods (Static, Access = private)
        function options = normalizeOptions(options)
            if ~isfield(options,'macroFolder') || isempty(options.macroFolder)
                options.macroFolder = ...
                    planWorkflow.macros.MacroFileResolver.defaultMacroFolder();
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

function browsePathInto(editHandle,titleText)
currentFolder = char(get(editHandle,'String'));
if isempty(currentFolder) || ~isfolder(currentFolder)
    currentFolder = pwd;
end
folder = uigetdir(currentFolder,titleText);
if isequal(folder,0)
    return;
end
set(editHandle,'String',folder);
end

function value = pathOptionDefault(value)
value = char(string(value));
if isempty(value)
    return;
end
if isfolder(value) || startsWith(value,filesep)
    return;
end
if ispc && ~isempty(regexp(value,'^[A-Za-z]:[\\/]', 'once'))
    return;
end
value = '';
end

function setProfilePopupValue(popup,value)
profile = char(string(value));
if isempty(profile)
    profile = 'prod';
end
values = popupValues(popup);
match = find(strcmpi(values,profile),1);
if isempty(match)
    match = 1;
end
set(popup,'Value',match);
end

function value = popupValue(popup)
values = popupValues(popup);
if isempty(values)
    value = '';
    return;
end
index = get(popup,'Value');
index = max(1,min(numel(values),index));
value = values{index};
end

function values = popupValues(popup)
values = get(popup,'String');
if ischar(values)
    values = cellstr(values);
else
    values = cellstr(string(values));
end
end

function output = runMacroFunction(functionName,args)
argList = args(:)';
nout = nargout(functionName);
if nout == 0
    feval(functionName,argList{:});
    output = [];
else
    output = feval(functionName,argList{:});
end
end

function text = argumentText(args)
if isempty(args)
    text = '(defaults)';
    return;
end
parts = cell(1,numel(args));
for i = 1:numel(args)
    if islogical(args{i})
        if args{i}
            parts{i} = 'true';
        else
            parts{i} = 'false';
        end
    else
        parts{i} = char(string(args{i}));
    end
end
text = strjoin(parts,', ');
end

function text = outputText(output)
if isempty(output)
    text = '(no output)';
elseif isstruct(output)
    text = sprintf('struct with %d field(s)',numel(fieldnames(output)));
else
    text = class(output);
end
end

function openFolder(folderPath)
folderPath = char(folderPath);
if isempty(folderPath) || ~isfolder(folderPath)
    errordlg(sprintf('Could not open folder "%s".',folderPath), ...
        'Open macro folder');
    return;
end
try
    if ispc
        winopen(folderPath);
    elseif ismac
        system(['open ' shellQuote(folderPath)]);
    else
        system(['xdg-open ' shellQuote(folderPath) ' &']);
    end
catch ME
    errordlg(sprintf('Could not open folder "%s": %s', ...
        folderPath,ME.message),'Open macro folder');
end
end

function quoted = shellQuote(value)
value = char(value);
if ispc
    quoted = ['"' strrep(value,'"','\"') '"'];
    return;
end
singleQuote = char(39);
escaped = strrep(value,singleQuote, ...
    [singleQuote '"' singleQuote '"' singleQuote]);
quoted = [singleQuote escaped singleQuote];
end
