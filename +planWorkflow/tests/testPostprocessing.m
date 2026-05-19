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
