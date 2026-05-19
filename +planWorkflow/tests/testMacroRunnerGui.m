function tests = testMacroRunnerGui
tests = functiontests(localfunctions);
end

function testMacroFileResolverDiscoversAndInspectsMacroSpecStyle(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
macroFile = fullfile(fixture.Folder,'nested','runExampleWorkflow.m');
helperFile = fullfile(fixture.Folder,'helpers','runWorkflowMacroSpec.m');
builderFile = fullfile(fixture.Folder,'openWorkflowMacroBuilder.m');
jobFile = fullfile(fixture.Folder,'jobs','runExampleJob.m');
writeTextFile(macroFile,strjoin({ ...
    'function result = runExampleWorkflow(varargin)', ...
    'profile = ''prod'';', ...
    'openGui = true;', ...
    'site = ''prostate'';', ...
    'particleType = ''photons'';', ...
    'caseID = ''3482'';', ...
    'robustness = ''multiple'';', ...
    'samplingProfile = ''default'';', ...
    'result = runWorkflowMacroSpec(''prostate.photons.3482.multiple'', ...', ...
    '    ''profile'',profile,''openGui'',openGui,varargin{:});', ...
    'end'},newline));
writeTextFile(helperFile,strjoin({ ...
    'function result = runWorkflowMacroSpec(varargin)', ...
    'result = planWorkflow.macros.MacroRunner.run(varargin{:});', ...
    'end'},newline));
writeTextFile(builderFile,strjoin({ ...
    'function openWorkflowMacroBuilder(varargin)', ...
    'workflow = planWorkflow.Workflow(struct()); %#ok<NASGU>', ...
    'end'},newline));
writeTextFile(jobFile,strjoin({ ...
    'function jobResult = runExampleJob(varargin)', ...
    'jobResult = runWorkflowMacroJob(struct(),varargin{:});', ...
    'end'},newline));

entries = planWorkflow.macros.MacroFileResolver.discover( ...
    {fixture.Folder,macroFile});
jobEntries = planWorkflow.macros.MacroFileResolver.discover(jobFile);
jobMetadata = planWorkflow.macros.MacroFileResolver.validate(jobFile);
metadata = planWorkflow.macros.MacroFileResolver.validate(macroFile);
rows = planWorkflow.macros.MacroFileResolver.summaryRows(metadata);
tableRows = planWorkflow.macros.MacroFileResolver.tableRows( ...
    entries,fixture.Folder);
args = planWorkflow.macros.MacroFileResolver.executionArguments( ...
    metadata,struct('caseID','4136','profile','testing', ...
    'rootPath','','cacheRootPath','','openGui',false));
filteredEntries = planWorkflow.macros.MacroFileResolver.filterEntries( ...
    entries,'example job');

entryNames = {entries.functionName};
tableFolders = tableRows(:,3);
filteredNames = {filteredEntries.functionName};
verifyEqual(testCase,numel(entries),1);
verifyEqual(testCase,numel(jobEntries),1);
verifyTrue(testCase,any(strcmp(entryNames,'runExampleWorkflow')));
verifyFalse(testCase,any(strcmp(entryNames,'runExampleJob')));
verifyEqual(testCase,jobEntries.functionName,'runExampleJob');
verifyTrue(testCase,jobMetadata.supportedOptions.profile);
verifyFalse(testCase,any(startsWith(tableFolders,fixture.Folder)));
verifyTrue(testCase,any(strcmp(tableFolders,'nested')));
verifyFalse(testCase,any(strcmp(tableFolders,'jobs')));
verifyEmpty(testCase,filteredNames);
verifyFalse(testCase,any(strcmp(entryNames,'runWorkflowMacroSpec')));
verifyFalse(testCase,any(strcmp(entryNames,'openWorkflowMacroBuilder')));
verifyEqual(testCase,metadata.defaults.caseID,'3482');
verifyEqual(testCase,metadata.defaults.openGui,true);
verifyTrue(testCase,metadata.supportedOptions.profile);
verifyTrue(testCase,metadata.supportedOptions.openGui);
verifyEqual(testCase,args, ...
    {'caseID','4136','profile','testing','openGui',false});
verifyTrue(testCase,any(strcmp(rows(:,1),'Function')));
verifyTrue(testCase,any(strcmp(rows(:,1),'Supports profile option')));
verifyError(testCase,@() ...
    planWorkflow.macros.MacroFileResolver.validate(helperFile), ...
    'planWorkflow:macros:MacroFileResolver:NotWorkflowMacro');
end

function testMacroFileResolverInspectsLegacyGuiMacro(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
macroFile = fullfile(fixture.Folder,'runLegacyWorkflow.m');
writeTextFile(macroFile,strjoin({ ...
    'function runLegacyWorkflow(varargin)', ...
    'macroDefaults = struct();', ...
    'macroDefaults.caseID = ''3482'';', ...
    'macroDefaults.rootPath = ''/tmp/userdata'';', ...
    'macroDefaults.cacheRootPath = fullfile(userDataRoot,''output'',''cache'');', ...
    'macroOptions = planWorkflow.gui.PlanPresetWriter.parseMacroOptions(macroDefaults,varargin{:});', ...
    'workflowConfig = struct(); %#ok<NASGU>', ...
    'end'},newline));

metadata = planWorkflow.macros.MacroFileResolver.validate(macroFile);
args = planWorkflow.macros.MacroFileResolver.executionArguments( ...
    metadata,struct('caseID','4136','rootPath','/tmp/alt', ...
    'cacheRootPath','','profile','testing','openGui',false));

verifyEqual(testCase,metadata.functionName,'runLegacyWorkflow');
verifyEqual(testCase,metadata.defaults.rootPath,'/tmp/userdata');
verifyFalse(testCase,metadata.supportedOptions.profile);
verifyFalse(testCase,metadata.supportedOptions.openGui);
verifyEqual(testCase,args,{'caseID','4136','rootPath','/tmp/alt'});
end

function testMacroFileResolverRejectsNameMismatch(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
macroFile = fullfile(fixture.Folder,'runExpectedWorkflow.m');
writeTextFile(macroFile,strjoin({ ...
    'function runOtherWorkflow(varargin)', ...
    'end'},newline));

verifyError(testCase,@() ...
    planWorkflow.macros.MacroFileResolver.validate(macroFile), ...
    'planWorkflow:macros:MacroFileResolver:NameMismatch');
end

function testMacroRunnerFrameCreatesResultsOnDemand(testCase)
if ~usejava('desktop')
    return;
end
oldVisible = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
cleanupVisibility = onCleanup( ...
    @() set(groot,'DefaultFigureVisible',oldVisible));

options = struct('macroFolder',tempdir);
callbacks = struct('close',@(~,~) []);
frame = planWorkflow.gui.MacroRunnerFrame.create(options,callbacks);
cleanupFig = onCleanup(@() closeFigure(frame.fig));

verifyTrue(testCase,hasTabTitle(frame.tabGroup,'Macro'));
verifyTrue(testCase,hasTabTitle(frame.tabGroup,'Spec'));
verifyTrue(testCase,hasTabTitle(frame.tabGroup,'Options'));
verifyFalse(testCase,hasTabTitle(frame.tabGroup,'Results'));
verifyTrue(testCase,ishandle(frame.searchEdit));
verifyTrue(testCase,ishandle(frame.clearSearchButton));
verifyTrue(testCase,ishandle(frame.profilePopup));
verifyTrue(testCase,ishandle(frame.runButton));
verifyTrue(testCase,ishandle(frame.validateButton));

frame = planWorkflow.gui.MacroRunnerFrame.showResultsTab( ...
    frame,'Validation',{'Status','Valid'});

verifyTrue(testCase,hasTabTitle(frame.tabGroup,'Results'));
verifyTrue(testCase,ishandle(frame.resultsTab));
end

function testMacroRunnerOpenEntrypointCreatesFrame(testCase)
if ~usejava('desktop')
    return;
end
oldVisible = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
cleanupVisibility = onCleanup( ...
    @() set(groot,'DefaultFigureVisible',oldVisible));

frame = planWorkflow.gui.MacroRunner.open( ...
    struct('macroFolder',tempdir));
cleanupFig = onCleanup(@() closeFigure(frame.fig));

verifyTrue(testCase,ishandle(frame.fig));
verifyTrue(testCase,hasTabTitle(frame.tabGroup,'Macro'));
verifyFalse(testCase,hasTabTitle(frame.tabGroup,'Results'));
end

function writeTextFile(filePath,text)
folder = fileparts(filePath);
if ~isempty(folder) && ~isfolder(folder)
    mkdir(folder);
end
fid = fopen(filePath,'w');
cleanupFile = onCleanup(@() fclose(fid));
fprintf(fid,'%s',text);
end

function closeFigure(fig)
if ~isempty(fig) && ishandle(fig)
    close(fig);
end
end

function tf = hasTabTitle(tabGroup,titleText)
tf = false;
tabs = get(tabGroup,'Children');
for i = 1:numel(tabs)
    if strcmp(get(tabs(i),'Title'),titleText)
        tf = true;
        return;
    end
end
end
