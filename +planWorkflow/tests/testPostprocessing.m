function tests = testPostprocessing
tests = functiontests(localfunctions);
end

function testResultSourceResolverFindsDirectAndRecursiveResults(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
directFile = fullfile(fixture.Folder,'workflow_results.mat');
nestedFolder = fullfile(fixture.Folder,'run with spaces','leaf');
nestedFile = fullfile(nestedFolder,'workflow_results.mat');
mkdir(nestedFolder);
touchFile(directFile);
touchFile(nestedFile);
directFile = canonicalPath(directFile);
nestedFile = canonicalPath(nestedFile);

files = planWorkflow.postprocessing.ResultSourceResolver.discover( ...
    {fixture.Folder,directFile});
rows = planWorkflow.postprocessing.ResultSourceResolver.tableRows(files);

verifyEqual(testCase,numel(files),2);
verifyTrue(testCase,any(strcmp(files,directFile)));
verifyTrue(testCase,any(strcmp(files,nestedFile)));
verifyEqual(testCase,size(rows,2),3);
end

function testCliCommandBuilderUsesSafeQuotedMultipleInputs(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
matFileA = fullfile(fixture.Folder,'run A','workflow_results.mat');
matFileB = fullfile(fixture.Folder,'run B','workflow_results.mat');
mkdir(fileparts(matFileA));
mkdir(fileparts(matFileB));
touchFile(matFileA);
touchFile(matFileB);
pythonExecutable = fullfile(fixture.Folder,'python');
touchFile(pythonExecutable);

config = planWorkflow.postprocessing.CliCommandBuilder.defaultConfig();
config.matFiles = {matFileA,matFileB};
config.outputDir = fullfile(fixture.Folder,'out dir');
config.pythonExecutable = pythonExecutable;
config.pythonPath = strjoin({ ...
    fullfile(fixture.Folder,'python module path'), ...
    fullfile(fixture.Folder,'dependency path')},pathsep);
config.filters = planWorkflow.postprocessing.CliCommandBuilder.filtersFromTableRows( ...
    {'include','patient','3482';'exclude','approach','c-Minimax'});

commands = planWorkflow.postprocessing.CliCommandBuilder.buildCommands(config);

verifyEqual(testCase,numel(commands),3);
verifyTrue(testCase,contains(commands{1},'planworkflow_postprocessing'));
verifyTrue(testCase,contains(commands{1}, ...
    planWorkflow.postprocessing.CliCommandBuilder.shellQuote(matFileA)));
verifyTrue(testCase,contains(commands{1}, ...
    planWorkflow.postprocessing.CliCommandBuilder.shellQuote(matFileB)));
verifyTrue(testCase,contains(commands{1}, ...
    planWorkflow.postprocessing.CliCommandBuilder.shellQuote(config.pythonPath)));
verifyTrue(testCase,contains(commands{1}, ...
    planWorkflow.postprocessing.CliCommandBuilder.shellQuote('patient=3482')));
verifyTrue(testCase,contains(commands{1}, ...
    planWorkflow.postprocessing.CliCommandBuilder.shellQuote('approach=c-Minimax')));
verifyTrue(testCase,contains(commands{2}, ...
    planWorkflow.postprocessing.CliCommandBuilder.shellQuote('relative')));
verifyTrue(testCase,contains(commands{3}, ...
    planWorkflow.postprocessing.CliCommandBuilder.shellQuote('relative')));
end

function testCliCommandBuilderDefaultsUseRelativeTimeAndSize(testCase)
config = planWorkflow.postprocessing.CliCommandBuilder.defaultConfig();

verifyEqual(testCase,config.timeValue,'relative');
verifyEqual(testCase,config.sizeValue,'relative');
verifyEqual(testCase,config.endpointStat,'por');
verifyEqual(testCase,config.endpointFilter,'all');
verifyTrue(testCase,contains(config.pythonExecutable, ...
    fullfile('.venv','bin','python')));
verifyEqual(testCase,config.pythonPath, ...
    planWorkflow.postprocessing.CliCommandBuilder.pythonPackagePath());
end

function testCliCommandBuilderRejectsMissingPythonExecutable(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
matFile = fullfile(fixture.Folder,'workflow_results.mat');
touchFile(matFile);

config = planWorkflow.postprocessing.CliCommandBuilder.defaultConfig();
config.matFiles = {matFile};
config.outputDir = fullfile(fixture.Folder,'out');
config.pythonExecutable = fullfile(fixture.Folder,'missing_python');

verifyError(testCase,@() ...
    planWorkflow.postprocessing.CliCommandBuilder.buildCommands(config), ...
    'planWorkflow:postprocessing:CliCommandBuilder:MissingPythonExecutable');
end

function testCliCommandBuilderRejectsPartialFilterRows(testCase)
verifyError(testCase,@() ...
    planWorkflow.postprocessing.CliCommandBuilder.filtersFromTableRows( ...
    {'include','patient',''}), ...
    'planWorkflow:postprocessing:CliCommandBuilder:InvalidFilter');
end

function testGeneratedFileIndexListsPngAndCsvOutputs(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
pngFile = fullfile(fixture.Folder,'precompute_dij_time_relative_boxplot.png');
csvFile = fullfile(fixture.Folder,'precompute_dij_time_relative_summary.csv');
txtFile = fullfile(fixture.Folder,'notes.txt');
imwrite(uint8(255 * ones(2,2,3)),pngFile);
touchFile(csvFile);
touchFile(txtFile);

pngEntries = planWorkflow.postprocessing.GeneratedFileIndex.pngEntries( ...
    fixture.Folder);
csvEntries = planWorkflow.postprocessing.GeneratedFileIndex.csvEntries( ...
    fixture.Folder);
rows = planWorkflow.postprocessing.GeneratedFileIndex.tableRows(pngEntries);

verifyEqual(testCase,numel(pngEntries),1);
verifyEqual(testCase,numel(csvEntries),1);
verifyEqual(testCase,rows(:,3),{'Open'});
verifyTrue(testCase,contains(pngEntries(1).label,'precompute dij time'));
end

function testPngViewerOpensPngInMatlabFigure(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
pngFile = fullfile(fixture.Folder,'plot.png');
imwrite(uint8(cat(3,[255 0;0 255],[0 255;255 0],[0 0;255 255])), ...
    pngFile);

fig = planWorkflow.postprocessing.PngViewer.open( ...
    pngFile,struct('Visible','off'));
cleanupFig = onCleanup(@() closeFigure(fig));

verifyTrue(testCase,ishandle(fig));
verifyEqual(testCase,char(get(fig,'Visible')),'off');
end

function testPostprocessingFrameCreatesResultsTabOnDemand(testCase)
if ~usejava('desktop')
    return;
end
oldVisible = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
cleanupVisibility = onCleanup( ...
    @() set(groot,'DefaultFigureVisible',oldVisible));

options = planWorkflow.postprocessing.CliCommandBuilder.defaultConfig();
callbacks = struct('close',@(~,~) []);
frame = planWorkflow.gui.PostprocessingEditorFrame.create( ...
    options,callbacks);
cleanupFig = onCleanup(@() closeFigure(frame.fig));

verifyTrue(testCase,hasTabTitle(frame.tabGroup,'Parameters'));
verifyFalse(testCase,hasTabTitle(frame.tabGroup,'Plots'));
verifyFalse(testCase,hasTabTitle(frame.tabGroup,'Results'));
verifyTrue(testCase,ishandle(frame.browsePythonButton));
verifyTrue(testCase,ishandle(frame.browsePythonPathButton));

entries = struct('id','plot','label','Plot', ...
    'filePath',fullfile(tempdir,'plot.png'),'kind','figure');
frame = planWorkflow.gui.PostprocessingEditorFrame.showResultsTab( ...
    frame,tempdir,entries,callbacks);

verifyTrue(testCase,hasTabTitle(frame.tabGroup,'Results'));
verifyTrue(testCase,ishandle(frame.resultsTab));
end

function testPostprocessingFrameShowsSingleNativeResultsAndPngFigures(testCase)
if ~usejava('desktop')
    return;
end
oldVisible = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
cleanupVisibility = onCleanup( ...
    @() set(groot,'DefaultFigureVisible',oldVisible));

fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
pngFile = fullfile(fixture.Folder,'endpoint_scatter.png');
imwrite(uint8(255 * ones(2,2,3)),pngFile);

options = planWorkflow.postprocessing.CliCommandBuilder.defaultConfig();
callbacks = struct('close',@(~,~) []);
frame = planWorkflow.gui.PostprocessingEditorFrame.create( ...
    options,callbacks);
cleanupFig = onCleanup(@() closeFigure(frame.fig));

entries = struct('id','endpoint','label','Endpoint scatter', ...
    'filePath',pngFile,'kind','figure');
nativeItems = nativeResultItem('Run A',fixture.Folder);
frame = planWorkflow.gui.PostprocessingEditorFrame.showResultsTab( ...
    frame,fixture.Folder,entries,nativeItems,callbacks);

verifyTrue(testCase,hasTabTitle(frame.tabGroup,'Results'));
verifyTrue(testCase,hasTabTitle(frame.resultGroup,'Reference'));
verifyTrue(testCase,hasTabTitle(frame.resultGroup, ...
    'Postprocessing figures'));
verifyFalse(testCase,hasTabTitle(frame.resultGroup,'Run A'));
referenceTabs = findall(frame.resultsTab,'Type','uitab', ...
    'Title','Reference');
verifyNotEmpty(testCase,referenceTabs);
referenceFigureTabs = findall(referenceTabs(1),'Type','uitab', ...
    'Title','Figures');
verifyNotEmpty(testCase,referenceFigureTabs);
robustTabs = findall(frame.resultsTab,'Type','uitab', ...
    'Title','Robust plan');
verifyNotEmpty(testCase,robustTabs);
robustFigureTabs = findall(robustTabs(1),'Type','uitab', ...
    'Title','Figures');
verifyNotEmpty(testCase,robustFigureTabs);
end

function testPostprocessingFrameShowsMultipleNativeResultSources(testCase)
if ~usejava('desktop')
    return;
end
oldVisible = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
cleanupVisibility = onCleanup( ...
    @() set(groot,'DefaultFigureVisible',oldVisible));

fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
pngFile = fullfile(fixture.Folder,'timing.png');
imwrite(uint8(255 * ones(2,2,3)),pngFile);

options = planWorkflow.postprocessing.CliCommandBuilder.defaultConfig();
callbacks = struct('close',@(~,~) []);
frame = planWorkflow.gui.PostprocessingEditorFrame.create( ...
    options,callbacks);
cleanupFig = onCleanup(@() closeFigure(frame.fig));

entries = struct('id','timing','label','Timing', ...
    'filePath',pngFile,'kind','figure');
nativeItems = [nativeResultItem('Run A',fixture.Folder) ...
    nativeResultItem('Run B',fixture.Folder)];
frame = planWorkflow.gui.PostprocessingEditorFrame.showResultsTab( ...
    frame,fixture.Folder,entries,nativeItems,callbacks);

verifyTrue(testCase,hasTabTitle(frame.resultGroup,'Run A'));
verifyTrue(testCase,hasTabTitle(frame.resultGroup,'Run B'));
verifyTrue(testCase,hasTabTitle(frame.resultGroup, ...
    'Postprocessing figures'));
referenceTabs = findall(frame.resultsTab,'Type','uitab', ...
    'Title','Reference');
verifyGreaterThanOrEqual(testCase,numel(referenceTabs),2);
nativeFigureTabs = findall(frame.resultsTab,'Type','uitab', ...
    'Title','Figures');
verifyGreaterThanOrEqual(testCase,numel(nativeFigureTabs),4);
end

function testWorkflowResultsLoaderLoadsCompactSyntheticResults(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
runFolder = fullfile(fixture.Folder,'synthetic_run');
samplingFolder = fullfile(runFolder,'sampling_analysis');
mkdir(runFolder);
mkdir(samplingFolder);
workflowFile = fullfile(runFolder,'workflow_results.mat');
referenceFigureFile = fullfile(samplingFolder,'reference_gamma.fig');
robustFigureFile = fullfile(samplingFolder,'robust_gamma.fig');
touchFile(referenceFigureFile);
touchFile(robustFigureFile);

results = syntheticNativeResults('loader-run');
results.sampling.reference.figureFiles = struct( ...
    'gamma','/remote/run/sampling_analysis/reference_gamma.fig');
results.sampling.reference.doseStat = struct('meanCube',ones(2), ...
    'stdCube',2 * ones(2));
results.sampling.robust = {struct( ...
    'expectedQi',struct('name','CTV','mean',79), ...
    'figureFiles',struct( ...
    'gamma','/remote/run/sampling_analysis/robust_gamma.fig'), ...
    'doseStat',struct('meanCube',3 * ones(2)))};
resultsMetadata = struct('runId','metadata-run'); %#ok<NASGU>
save(workflowFile,'results','resultsMetadata');

item = planWorkflow.postprocessing.WorkflowResultsLoader.load( ...
    workflowFile);

verifyEqual(testCase,item.sourceFile,canonicalPath(workflowFile));
verifyEqual(testCase,item.label,'loader-run');
verifyTrue(testCase,isfield(item.results,'performance'));
verifyTrue(testCase,isfield(item.results.sampling.reference,'figureFiles'));
verifyTrue(testCase,isfield(item.results.sampling.robust{1}, ...
    'figureFiles'));
verifyEqual(testCase,item.results.sampling.reference.figureFiles.gamma, ...
    referenceFigureFile);
verifyEqual(testCase,item.results.sampling.robust{1}.figureFiles.gamma, ...
    robustFigureFile);
verifyFalse(testCase,isfield( ...
    item.results.sampling.reference.doseStat,'meanCube'));
verifyFalse(testCase,isfield( ...
    item.results.sampling.robust{1}.doseStat,'meanCube'));
end

function touchFile(filePath)
folder = fileparts(filePath);
if ~isempty(folder) && ~isfolder(folder)
    mkdir(folder);
end
fid = fopen(filePath,'w');
cleanupFile = onCleanup(@() fclose(fid));
fprintf(fid,'test');
end

function closeFigure(fig)
if ~isempty(fig) && ishandle(fig)
    close(fig);
end
end

function item = nativeResultItem(label,figureFolder)
if nargin < 2
    figureFolder = tempdir;
end
item = struct( ...
    'sourceFile',fullfile(tempdir,[char(label) '.mat']), ...
    'label',char(label), ...
    'results',syntheticNativeResults(label,figureFolder));
end

function results = syntheticNativeResults(runId,figureFolder)
if nargin < 2
    figureFolder = '';
end
results = struct();
results.runConfig = struct('runId',char(runId));
results.sampling.reference.expectedQi = struct( ...
    'name','CTV','COV1',1,'mean',78);
results.sampling.robust = {struct( ...
    'label','Robust plan', ...
    'expectedQi',struct('name','CTV','COV1',1,'mean',79))};
if ~isempty(figureFolder)
    figurePrefix = regexprep(char(runId),'[^A-Za-z0-9_]','_');
    referenceFigure = fullfile(figureFolder, ...
        [figurePrefix '_reference_gamma.fig']);
    robustFigure = fullfile(figureFolder, ...
        [figurePrefix '_robust_gamma.fig']);
    touchFile(referenceFigure);
    touchFile(robustFigure);
    results.sampling.reference.figureFiles = struct( ...
        'gamma',referenceFigure);
    results.sampling.robust{1}.figureFiles = struct( ...
        'gamma',robustFigure);
end
results.performance.stageTimings.prepare = struct( ...
    'lastStatus','completed','attempts',1);
end

function path = canonicalPath(path)
path = char(java.io.File(path).getCanonicalPath());
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
