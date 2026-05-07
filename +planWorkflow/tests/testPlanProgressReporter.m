function tests = testPlanProgressReporter
tests = functiontests(localfunctions);
end

function testFigureEntriesUseSavedSamplingFiguresOnly(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
gammaFile = fullfile(fixture.Folder,'reference_gamma.fig');
meanDoseFile = fullfile(fixture.Folder,'reference_mean_dose.fig');
missingFile = fullfile(fixture.Folder,'missing.fig');
touchFile(gammaFile);
touchFile(meanDoseFile);

planResults = struct();
planResults.figureFiles = struct();
planResults.figureFiles.gamma = gammaFile;
planResults.figureFiles.robustness1 = missingFile;
planResults.figureFiles.meanDose = string(meanDoseFile);
planResults.figureFiles.stdDose = '';

entries = planWorkflow.gui.PlanProgressReporter.figureEntries(planResults);
rows = planWorkflow.gui.PlanProgressReporter.figureTableRows(entries);

verifyEqual(testCase,{entries.id},{'gamma','meanDose'});
verifyEqual(testCase,{entries.label},{'Gamma','Mean dose'});
verifyEqual(testCase,{entries.filePath}, ...
    {gammaFile,meanDoseFile});
verifyEqual(testCase,rows(:,1),{'Gamma';'Mean dose'});
verifyEqual(testCase,rows(:,3),{'Open';'Open'});
verifyEqual(testCase,size(rows,2),3);
verifyEqual(testCase, ...
    planWorkflow.gui.PlanProgressReporter.figureFolder(entries), ...
    fixture.Folder);
end

function testFigureEntriesIgnoreResultsWithoutFigures(testCase)
entries = planWorkflow.gui.PlanProgressReporter.figureEntries(struct());

verifyEmpty(testCase,entries);
end

function testPerformanceRowsShowStageTimingAndMemory(testCase)
resources = syntheticPerformanceResources();

rows = planWorkflow.gui.PlanProgressReporter.performanceRows(resources);
modelRows = planWorkflow.gui.PerformanceTableModel.stageRows(resources);

verifyEqual(testCase,rows,modelRows);
verifyEqual(testCase,rows(1,1:3),{'Prepare','completed','1'});
verifyEqual(testCase,rows{1,6},'12.346');
verifyEqual(testCase,rows{1,7},'4.500');
verifyEqual(testCase,rows{1,8},'100.00');
verifyEqual(testCase,rows{1,10},'25.00');
verifyEqual(testCase,rows{1,14},'2.00');
verifyEqual(testCase,rows{1,15},'process_rss_ps');
end

function testPlanPerformanceRowsShowPlanTimingAndMemory(testCase)
resources = syntheticPerformanceResources();

rows = planWorkflow.gui.PlanProgressReporter.planPerformanceRows(resources);
modelRows = planWorkflow.gui.PerformanceTableModel.planRows(resources);

verifyEqual(testCase,rows,modelRows);
verifyEqual(testCase, ...
    planWorkflow.gui.PlanProgressReporter.planPerformanceColumnNames(), ...
    {'Stage','Role','Plan','Task','Variant','Status','Start','End', ...
    'Wall time (s)','CPU time (s)','Process delta (MB)', ...
    'Process max (MB)','Data delta (MB)','Memory source','Detail JSON', ...
    'Error'});
verifyEqual(testCase,rows(1,1:6), ...
    {'Optimize','robust','Robust interval2','fluenceOptimization', ...
    'p1_1','completed'});
verifyEqual(testCase,rows{1,9},'7.250');
verifyEqual(testCase,rows{1,10},'3.125');
verifyEqual(testCase,rows{1,11},'30.00');
verifyEqual(testCase,rows{1,13},'4.00');
verifyEqual(testCase,rows{1,14},'process_rss_ps');
detailData = jsondecode(rows{1,15});
verifyEqual(testCase,detailData.iterations,12);
verifyEqual(testCase,rows{1,16},'-');
end

function testProgressLogScrollsToLatestMessage(testCase)
guiFig = figure('Visible','off');
cleanupGui = onCleanup(@() closeFigure(guiFig));
fill = uipanel('Parent',guiFig,'Position',[0 0 0 1]);
status = uicontrol('Parent',guiFig,'Style','text');
details = uicontrol('Parent',guiFig,'Style','listbox');
stopButton = uicontrol('Parent',guiFig,'Style','pushbutton');
tabGroup = uitabgroup('Parent',guiFig);
reporter = planWorkflow.gui.PlanProgressReporter( ...
    guiFig,fill,status,details,stopButton,tabGroup);

for i = 1:30
    reporter.log(sprintf('Message %d.',i));
end

messages = cellstr(get(details,'String'));
verifyEqual(testCase,numel(messages),30);
verifyTrue(testCase,contains(messages{end},'Message 30.'));
verifyEqual(testCase,get(details,'Value'),30);
try
    verifyGreaterThan(testCase,get(details,'ListboxTop'),1);
catch ME
    if ~strcmp(ME.identifier,'MATLAB:class:InvalidProperty')
        rethrow(ME);
    end
end
end

function testStageProgressAddsVisibleLogMessages(testCase)
guiFig = figure('Visible','off');
cleanupGui = onCleanup(@() closeFigure(guiFig));
fill = uipanel('Parent',guiFig,'Position',[0 0 0 1]);
status = uicontrol('Parent',guiFig,'Style','text');
details = uicontrol('Parent',guiFig,'Style','listbox');
stopButton = uicontrol('Parent',guiFig,'Style','pushbutton');
tabGroup = uitabgroup('Parent',guiFig);
reporter = planWorkflow.gui.PlanProgressReporter( ...
    guiFig,fill,status,details,stopButton,tabGroup);

reporter.stageStarted('sample',5,6);
reporter.stageProgress('sample',0.25, ...
    'Plan reference: 1/4 scenarios.');
reporter.stageProgress('sample',0.50, ...
    'Plan reference: 2/4 scenarios.');
reporter.stageProgress('sample',0.50, ...
    'Plan reference: 2/4 scenarios.');

messages = cellstr(get(details,'String'));
verifyTrue(testCase,any(contains(messages, ...
    'Sampling: Plan reference: 1/4 scenarios.')));
verifyEqual(testCase,sum(contains(messages, ...
    'Sampling: Plan reference: 2/4 scenarios.')),1);
verifyEqual(testCase,get(details,'Value'),numel(messages));
verifyTrue(testCase,contains(get(status,'String'), ...
    'Sampling: Plan reference: 2/4 scenarios.'));
end

function testShowResultsShowsSamplingFigurePanel(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
figureFile = fullfile(fixture.Folder,'reference_gamma.fig');
touchFile(figureFile);

guiFig = figure('Visible','off');
cleanupGui = onCleanup(@() closeFigure(guiFig));
fill = uipanel('Parent',guiFig,'Position',[0 0 0 1]);
status = uicontrol('Parent',guiFig,'Style','text');
details = uicontrol('Parent',guiFig,'Style','listbox');
stopButton = uicontrol('Parent',guiFig,'Style','pushbutton');
tabGroup = uitabgroup('Parent',guiFig);
reporter = planWorkflow.gui.PlanProgressReporter( ...
    guiFig,fill,status,details,stopButton,tabGroup);

results = struct();
results.sampling.reference.figureFiles = struct('gamma',figureFile);

reporter.showResults(results);

figureTabs = findall(guiFig,'Type','uitab','Title','Figures');
verifyNotEmpty(testCase,figureTabs);
tables = findall(figureTabs(1),'Type','uitable');
verifyEmpty(testCase,tables);
figurePanels = findall(figureTabs(1),'Type','uipanel', ...
    'Tag','planWorkflowSamplingFiguresPanel');
verifyNotEmpty(testCase,figurePanels);
folderFields = findall(figurePanels(1),'Style','edit', ...
    'String',fixture.Folder);
verifyNotEmpty(testCase,folderFields);
figureFields = findall(figurePanels(1),'Style','edit', ...
    'String','reference_gamma.fig');
verifyNotEmpty(testCase,figureFields);
openButtons = findall(figureTabs(1),'Style','pushbutton','String','Open');
verifyGreaterThanOrEqual(testCase,numel(openButtons),2);
end

function testSamplingExpectedQiUsesSeparateTab(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);
figureFile = fullfile(fixture.Folder,'reference_gamma.fig');
touchFile(figureFile);

guiFig = figure('Visible','off');
cleanupGui = onCleanup(@() closeFigure(guiFig));
fill = uipanel('Parent',guiFig,'Position',[0 0 0 1]);
status = uicontrol('Parent',guiFig,'Style','text');
details = uicontrol('Parent',guiFig,'Style','listbox');
stopButton = uicontrol('Parent',guiFig,'Style','pushbutton');
tabGroup = uitabgroup('Parent',guiFig);
reporter = planWorkflow.gui.PlanProgressReporter( ...
    guiFig,fill,status,details,stopButton,tabGroup);

results = struct();
results.sampling.reference.evaluationMode = 'total';
results.sampling.reference.evaluationModeBase = 'perFraction';
results.sampling.reference.evaluationScale = 39;
results.sampling.reference.figureFiles = struct('gamma',figureFile);
results.sampling.reference.expectedQiSource = 'expected qi source';
results.sampling.reference.expectedDvhSource = 'expected dvh source';
results.sampling.reference.expectedQi = struct( ...
    'name','CTV','COV1',1,'COV_95',0.95,'COV_98',0.98, ...
    'COV_99',0.99,'mean',78,'spatialStdDose',1, ...
    'uncertaintyHalfWidth',0.5,'min',70,'max',82, ...
    'D_95',76,'D_98',75,'D_2',81,'D_50',78);
results.reference.qi = results.sampling.reference.expectedQi;

reporter.showResults(results);

summaryTabs = findall(guiFig,'Type','uitab','Title','Summary');
verifyNotEmpty(testCase,summaryTabs);
tables = findall(summaryTabs(1),'Type','uitable');
verifyEmpty(testCase,tables);
summaryPanels = findall(summaryTabs(1),'Type','uipanel', ...
    'Tag','planWorkflowSamplingSummaryPanel');
verifyNotEmpty(testCase,summaryPanels);
summaryLabels = findall(summaryPanels(1),'Style','text', ...
    'String','Sampling figures');
verifyEmpty(testCase,summaryLabels);
expectedQiSourceLabels = findall(summaryPanels(1),'Style','text', ...
    'String','Expected QI source');
verifyEmpty(testCase,expectedQiSourceLabels);
expectedDvhSourceLabels = findall(summaryPanels(1),'Style','text', ...
    'String','Expected DVH source');
verifyEmpty(testCase,expectedDvhSourceLabels);

samplingTabs = findall(guiFig,'Type','uitab','Title','Reference');
verifyNotEmpty(testCase,samplingTabs);
nominalQiTabs = findall(samplingTabs(1),'Type','uitab', ...
    'Title','Nominal QI');
verifyNotEmpty(testCase,nominalQiTabs);
nominalQiTables = findall(nominalQiTabs(1),'Type','uitable');
verifyNumElements(testCase,nominalQiTables,1);
nominalQiColumnNames = get(nominalQiTables(1),'ColumnName');
verifyEqual(testCase,nominalQiColumnNames(:)', ...
    {'Structure','COV1','COV95','COV98','COV99', ...
    'Mean','SpatialSD','UncertHW','Min','Max','D95','D98','D2','D50'});
gammaAnalysisLabels = findall(nominalQiTabs(1),'Style','text', ...
    'String','Gamma pass rate');
verifyEmpty(testCase,gammaAnalysisLabels);
qiTabs = findall(guiFig,'Type','uitab','Title','Expected QI');
verifyNotEmpty(testCase,qiTabs);
qiTables = findall(qiTabs(1),'Type','uitable');
verifyNumElements(testCase,qiTables,1);
qiColumnNames = get(qiTables(1),'ColumnName');
verifyEqual(testCase,qiColumnNames(:)', ...
    {'Structure','COV1','COV95','COV98','COV99', ...
    'Mean','SpatialSD','UncertHW','Min','Max','D95','D98','D2','D50'});
qiData = get(qiTables(1),'Data');
verifyEqual(testCase,qiData{1,1},'CTV');
end

function testSamplingClinicalEndpointsUseSeparateTab(testCase)
guiFig = figure('Visible','off');
cleanupGui = onCleanup(@() closeFigure(guiFig));
fill = uipanel('Parent',guiFig,'Position',[0 0 0 1]);
status = uicontrol('Parent',guiFig,'Style','text');
details = uicontrol('Parent',guiFig,'Style','listbox');
stopButton = uicontrol('Parent',guiFig,'Style','pushbutton');
tabGroup = uitabgroup('Parent',guiFig);
reporter = planWorkflow.gui.PlanProgressReporter( ...
    guiFig,fill,status,details,stopButton,tabGroup);

results = struct();
results.runConfig = struct('description','prostate');
results.runConfig.analysis = struct( ...
    'gammaCriteria',[3 3], ...
    'gammaWindow',[0 1], ...
    'robustnessTargetMode','include', ...
    'robustnessTargets',{{'CTV','PTV'}});
results.runConfig.precompute.robustPlans = struct( ...
    'id','interval2', ...
    'label','INTERVAL2', ...
    'objectiveSetName','interval2', ...
    'robustnessMode','INTERVAL2', ...
    'scenario',planWorkflow.config.RobustPlanConfig.defaultScenario( ...
    'wcScen'), ...
    'variants',struct('id','theta_5','label','Variant 1','theta1',5));
results.sampling.reference.evaluationMode = 'total';
results.sampling.reference.evaluationModeBase = 'total';
results.sampling.reference.evaluationScale = 1;
results.sampling.reference.analysisQuantity = 'physicalDose';
results.sampling.reference.cstStat = samplingStructureStat( ...
    'BLADDER',[100 90 50 0]);
results.sampling.reference.doseStat.robustnessAnalysis.index1 = ...
    struct('robustnessIndex',0.81234);
results.sampling.reference.doseStat.robustnessAnalysis.index2 = ...
    struct('robustnessIndex',0.73456);
results.sampling.robust = {struct( ...
    'label','INTERVAL2 / Variant 1', ...
    'evaluationMode','total', ...
    'evaluationModeBase','total', ...
    'evaluationScale',1, ...
    'analysisQuantity','physicalDose', ...
    'cstStat',samplingStructureStat('BLADDER',[100 95 65 0]), ...
    'doseStat',struct('robustnessAnalysis',struct( ...
    'index1',struct('robustnessIndex',0.65432), ...
    'index2',struct('robustnessIndex',0.54321))))};
results.performance.planTimings = syntheticSamplingPlanTimings();

reporter.showResults(results);

samplingTabs = findall(guiFig,'Type','uitab','Title','Reference');
verifyNotEmpty(testCase,samplingTabs);

summaryTabs = findall(samplingTabs(1),'Type','uitab','Title','Summary');
verifyNotEmpty(testCase,summaryTabs);
summaryTables = findall(summaryTabs(1),'Type','uitable');
verifyEmpty(testCase,summaryTables);
summaryPanels = findall(summaryTabs(1),'Type','uipanel', ...
    'Tag','planWorkflowSamplingSummaryPanel');
verifyNotEmpty(testCase,summaryPanels);
evaluationModeLabels = findall(summaryPanels(1),'Style','text', ...
    'String','Evaluation mode');
verifyNotEmpty(testCase,evaluationModeLabels);
evaluationParameterSections = findall(summaryPanels(1),'Style','text', ...
    'String','Evaluation parameters');
verifyNotEmpty(testCase,evaluationParameterSections);
gammaSections = findall(summaryPanels(1),'Style','text', ...
    'String','Gamma');
verifyNotEmpty(testCase,gammaSections);
gammaCriteriaLabels = findall(summaryPanels(1),'Style','text', ...
    'String','Gamma criteria');
verifyNotEmpty(testCase,gammaCriteriaLabels);
robustnessSections = findall(summaryPanels(1),'Style','text', ...
    'String','Robustness');
verifyNotEmpty(testCase,robustnessSections);
targetLabels = findall(summaryPanels(1),'Style','text', ...
    'String','Targets');
verifyNotEmpty(testCase,targetLabels);
targetValues = findall(summaryPanels(1),'Style','edit', ...
    'String','include: CTV, PTV');
verifyNotEmpty(testCase,targetValues);
robustnessIndexLabels = findall(summaryPanels(1),'Style','text', ...
    'String','RI1');
verifyNotEmpty(testCase,robustnessIndexLabels);
robustnessIndex2Labels = findall(summaryPanels(1),'Style','text', ...
    'String','RI2');
verifyNotEmpty(testCase,robustnessIndex2Labels);
ri1Values = findall(summaryPanels(1),'Style','edit', ...
    'String','0.812');
verifyNotEmpty(testCase,ri1Values);
ri2Values = findall(summaryPanels(1),'Style','edit', ...
    'String','0.735');
verifyNotEmpty(testCase,ri2Values);
riHelpLabels = findall(summaryPanels(1),'Style','text', ...
    'String','RI help');
verifyEmpty(testCase,riHelpLabels);
ri1HelpTexts = findTextControlsContaining(summaryPanels(1), ...
    {'Delta Index'});
verifyNotEmpty(testCase,ri1HelpTexts);
ri2HelpTexts = findTextControlsContaining(summaryPanels(1), ...
    {'binary'});
verifyNotEmpty(testCase,ri2HelpTexts);
verifyNotEqual(testCase,ri1HelpTexts(1),ri2HelpTexts(1));
verifyFalse(testCase,contains(controlString(ri1HelpTexts(1)),'RI1:'));
verifyFalse(testCase,contains(controlString(ri2HelpTexts(1)),'RI2:'));
verifyEqual(testCase,get(ri1HelpTexts(1),'TooltipString'),'');
verifyEqual(testCase,get(ri2HelpTexts(1),'TooltipString'),'');
ri1Position = get(robustnessIndexLabels(1),'Position');
ri2Position = get(robustnessIndex2Labels(1),'Position');
ri1HelpPosition = get(ri1HelpTexts(1),'Position');
ri2HelpPosition = get(ri2HelpTexts(1),'Position');
verifyLessThan(testCase,ri1HelpPosition(2),ri1Position(2));
verifyGreaterThan(testCase,ri1HelpPosition(2),ri2Position(2));
verifyLessThan(testCase,ri2HelpPosition(2),ri2Position(2));
verifyLessThan(testCase,ri2HelpPosition(2),ri1HelpPosition(2));
verifyEqual(testCase,ri1HelpPosition(3), ...
    planWorkflow.gui.TextLayout.helpTextWidth(),'AbsTol',1e-12);
verifyEqual(testCase,ri2HelpPosition(3), ...
    planWorkflow.gui.TextLayout.helpTextWidth(),'AbsTol',1e-12);

clinicalTabs = findall(samplingTabs(1),'Type','uitab', ...
    'Title','Clinical endpoints');
verifyNotEmpty(testCase,clinicalTabs);
clinicalTables = findall(clinicalTabs(1),'Type','uitable');
verifyNumElements(testCase,clinicalTables,1);
clinicalColumnNames = get(clinicalTables(1),'ColumnName');
verifyEqual(testCase,clinicalColumnNames(:)', ...
    {'Structure','Metric','Mean','UncertHW','Min','Max','Delta','Goal', ...
    'PoR','Unit'});
clinicalData = get(clinicalTables(1),'Data');
verifyEqual(testCase,clinicalData(1,1:2),{'BLADDER','V60'});
verifyEqual(testCase,clinicalData{1,9},0);

robustSamplingTabs = findall(guiFig,'Type','uitab', ...
    'Title','INTERVAL2 (theta1=5)');
verifyNotEmpty(testCase,robustSamplingTabs);
oldRobustSamplingTabs = findall(guiFig,'Type','uitab', ...
    'Title','INTERVAL2 / Variant 1');
verifyEmpty(testCase,oldRobustSamplingTabs);
oldPrefixedRobustSamplingTabs = findall(guiFig,'Type','uitab', ...
    'Title','Sampling INTERVAL2 (theta1=5)');
verifyEmpty(testCase,oldPrefixedRobustSamplingTabs);
robustClinicalTabs = findall(robustSamplingTabs(1),'Type','uitab', ...
    'Title','Clinical endpoints');
verifyNotEmpty(testCase,robustClinicalTabs);
robustClinicalTables = findall(robustClinicalTabs(1),'Type','uitable');
verifyNumElements(testCase,robustClinicalTables,1);
robustClinicalData = get(robustClinicalTables(1),'Data');
verifyEqual(testCase,robustClinicalData(1,1:2),{'BLADDER','V60'});
verifyEqual(testCase,robustClinicalData{1,3},65);
verifyEqual(testCase,robustClinicalData{1,7},15);
verifyEqual(testCase,robustClinicalData{1,9},-15);

robustSummaryTabs = findall(robustSamplingTabs(1),'Type','uitab', ...
    'Title','Summary');
verifyNotEmpty(testCase,robustSummaryTabs);
robustSummaryPanels = findall(robustSummaryTabs(1),'Type','uipanel', ...
    'Tag','planWorkflowSamplingSummaryPanel');
verifyNotEmpty(testCase,robustSummaryPanels);
porSections = findall(robustSummaryPanels(1),'Style','text', ...
    'String','Price of Robustness');
verifyNotEmpty(testCase,porSections);
porEndpointLabels = findall(robustSummaryPanels(1),'Style','text', ...
    'String','BLADDER - V60');
verifyNotEmpty(testCase,porEndpointLabels);
porValues = findall(robustSummaryPanels(1),'Style','edit', ...
    'String','-15 %');
verifyNotEmpty(testCase,porValues);
performanceSections = findall(robustSummaryPanels(1),'Style','text', ...
    'String','Performance');
verifyNotEmpty(testCase,performanceSections);
robustGammaSections = findall(robustSummaryPanels(1),'Style','text', ...
    'String','Gamma');
verifyNotEmpty(testCase,robustGammaSections);
robustRobustnessSections = findall(robustSummaryPanels(1), ...
    'Style','text','String','Robustness');
verifyNotEmpty(testCase,robustRobustnessSections);
gammaPosition = get(robustGammaSections(1),'Position');
robustnessPosition = get(robustRobustnessSections(1),'Position');
porPosition = get(porSections(1),'Position');
performancePosition = get(performanceSections(1),'Position');
verifyGreaterThan(testCase,gammaPosition(2),robustnessPosition(2));
verifyGreaterThan(testCase,robustnessPosition(2),porPosition(2));
verifyGreaterThan(testCase,porPosition(2),performancePosition(2));
precomputeTimeLabels = findall(robustSummaryPanels(1),'Style','text', ...
    'String','Precompute wall time (s)');
verifyNotEmpty(testCase,precomputeTimeLabels);
precomputeTimeValues = findall(robustSummaryPanels(1),'Style','edit', ...
    'String','4.500');
verifyNotEmpty(testCase,precomputeTimeValues);
precomputeCpuLabels = findall(robustSummaryPanels(1),'Style','text', ...
    'String','Precompute CPU time (s)');
verifyNotEmpty(testCase,precomputeCpuLabels);
precomputeCpuValues = findall(robustSummaryPanels(1),'Style','edit', ...
    'String','2.250');
verifyNotEmpty(testCase,precomputeCpuValues);
precomputeDetailLabels = findall(robustSummaryPanels(1),'Style','text', ...
    'String','Precompute Detail JSON');
verifyNotEmpty(testCase,precomputeDetailLabels);
precomputeDetailValues = findEditControlsContaining( ...
    robustSummaryPanels(1),{'dij_robust'});
verifyNotEmpty(testCase,precomputeDetailValues);
precomputeDetailTexts = controlStrings(precomputeDetailValues);
verifyTrue(testCase,any(contains(precomputeDetailTexts,'tasks:')));
verifyTrue(testCase,any(contains(precomputeDetailTexts,'dij_robust:')));
verifyTrue(testCase,any(contains(precomputeDetailTexts,newline)));
verifyFalse(testCase,any(contains(precomputeDetailTexts,'{"tasks"')));
optimizeTimeLabels = findall(robustSummaryPanels(1),'Style','text', ...
    'String','Optimize wall time (s)');
verifyNotEmpty(testCase,optimizeTimeLabels);
optimizeTimeValues = findall(robustSummaryPanels(1),'Style','edit', ...
    'String','7.250');
verifyNotEmpty(testCase,optimizeTimeValues);
optimizeCpuLabels = findall(robustSummaryPanels(1),'Style','text', ...
    'String','Optimize CPU time (s)');
verifyNotEmpty(testCase,optimizeCpuLabels);
optimizeCpuValues = findall(robustSummaryPanels(1),'Style','edit', ...
    'String','3.125');
verifyNotEmpty(testCase,optimizeCpuValues);
optimizeDetailLabels = findall(robustSummaryPanels(1),'Style','text', ...
    'String','Optimize Detail JSON');
verifyNotEmpty(testCase,optimizeDetailLabels);
optimizeDetailValues = findEditControlsContaining( ...
    robustSummaryPanels(1),{'iterations'});
verifyNotEmpty(testCase,optimizeDetailValues);
verifyTrue(testCase,any(contains( ...
    controlStrings(optimizeDetailValues),'iterations: 12')));
verifyEmpty(testCase,findall(robustSummaryPanels(1),'Style','text', ...
    'String','Precompute process max (MB)'));
verifyEmpty(testCase,findall(robustSummaryPanels(1),'Style','text', ...
    'String','Precompute data delta (MB)'));
verifyEmpty(testCase,findall(robustSummaryPanels(1),'Style','text', ...
    'String','Optimize process max (MB)'));
verifyEmpty(testCase,findall(robustSummaryPanels(1),'Style','text', ...
    'String','Optimize data delta (MB)'));
end

function testReadOnlyPanelsAreScrollableAndKeepOverflowRows(testCase)
guiFig = figure('Visible','off');
cleanupGui = onCleanup(@() closeFigure(guiFig));
fill = uipanel('Parent',guiFig,'Position',[0 0 0 1]);
status = uicontrol('Parent',guiFig,'Style','text');
details = uicontrol('Parent',guiFig,'Style','listbox');
stopButton = uicontrol('Parent',guiFig,'Style','pushbutton');
tabGroup = uitabgroup('Parent',guiFig);
reporter = planWorkflow.gui.PlanProgressReporter( ...
    guiFig,fill,status,details,stopButton,tabGroup);

robustness = struct();
robustness.index1 = struct('robustnessIndex',0.45678);
robustness.index2 = struct('robustnessIndex',0.87654);
results = struct();
results.runConfig.precompute.robustPlans = struct( ...
    'id','interval2', ...
    'label','INTERVAL2', ...
    'objectiveSetName','interval2', ...
    'robustnessMode','INTERVAL2', ...
    'scenario',planWorkflow.config.RobustPlanConfig.defaultScenario( ...
    'wcScen'), ...
    'variants',struct('id','theta_5','label','Variant 1','theta1',5));
results.performance.planTimings = syntheticSamplingPlanTimings();
results.sampling.robust = {struct( ...
    'label','INTERVAL2 / Variant 1', ...
    'evaluationMode','total', ...
    'doseStat',struct('robustnessAnalysis',robustness))};

reporter.showResults(results);

summaryPanels = findall(guiFig,'Type','uipanel', ...
    'Tag','planWorkflowSamplingSummaryPanel');
verifyNotEmpty(testCase,summaryPanels);
if ~isempty(summaryPanels)
    if isprop(summaryPanels(1),'Scrollable')
        verifyNotEqual(testCase,char(get(summaryPanels(1),'Scrollable')),'on');
    end
    scrollSliders = findall(summaryPanels(1),'Style','slider', ...
        'Tag','planWorkflowSamplingSummaryPanelScrollSlider');
    verifyNotEmpty(testCase,scrollSliders);
    overflowLabels = findall(summaryPanels(1),'Style','text', ...
        'String','Optimize Detail JSON');
    verifyNotEmpty(testCase,overflowLabels);
end
end

function testShowResultsOmitsNonSamplingAnalysisTabs(testCase)
guiFig = figure('Visible','off');
cleanupGui = onCleanup(@() closeFigure(guiFig));
fill = uipanel('Parent',guiFig,'Position',[0 0 0 1]);
status = uicontrol('Parent',guiFig,'Style','text');
details = uicontrol('Parent',guiFig,'Style','listbox');
stopButton = uicontrol('Parent',guiFig,'Style','pushbutton');
tabGroup = uitabgroup('Parent',guiFig);
reporter = planWorkflow.gui.PlanProgressReporter( ...
    guiFig,fill,status,details,stopButton,tabGroup);

results = struct();
results.reference.expectedQi = struct('name','CTV','expectedValue',1);
results.robust = {struct('expectedQi',struct('name','CTV', ...
    'expectedValue',2))};
results.sampling.reference.expectedQi = results.reference.expectedQi;

reporter.showResults(results);

robustTabs = findall(guiFig,'Type','uitab','Title','Robust 1');
samplingTabs = findall(guiFig,'Type','uitab','Title','Reference');
topTitles = tabTitles(get(tabGroup,'Children'));
verifyFalse(testCase,any(strcmp(topTitles,'Reference')));
verifyEmpty(testCase,robustTabs);
verifyNotEmpty(testCase,samplingTabs);
end

function testShowResultsDoesNotAddReferenceLabelTab(testCase)
guiFig = figure('Visible','off');
cleanupGui = onCleanup(@() closeFigure(guiFig));
fill = uipanel('Parent',guiFig,'Position',[0 0 0 1]);
status = uicontrol('Parent',guiFig,'Style','text');
details = uicontrol('Parent',guiFig,'Style','listbox');
stopButton = uicontrol('Parent',guiFig,'Style','pushbutton');
tabGroup = uitabgroup('Parent',guiFig);
reporter = planWorkflow.gui.PlanProgressReporter( ...
    guiFig,fill,status,details,stopButton,tabGroup);

results = struct();
results.runConfig.reference_label = 'Nominal';
results.reference.expectedQi = struct('name','CTV','expectedValue',1);
results.sampling.reference.expectedQi = results.reference.expectedQi;

reporter.showResults(results);

referenceTabs = findall(guiFig,'Type','uitab', ...
    'Title','Reference (Nominal)');
verifyNotEmpty(testCase,referenceTabs);
topTitles = tabTitles(get(tabGroup,'Children'));
verifyFalse(testCase,any(strcmp(topTitles,'Reference (Nominal)')));
end

function testResultsTabRecalculateAnalysisButtonRunsCallback(testCase)
guiFig = figure('Visible','off');
cleanupGui = onCleanup(@() closeFigure(guiFig));
fill = uipanel('Parent',guiFig,'Position',[0 0 0 1]);
status = uicontrol('Parent',guiFig,'Style','text');
details = uicontrol('Parent',guiFig,'Style','listbox');
stopButton = uicontrol('Parent',guiFig,'Style','pushbutton');
tabGroup = uitabgroup('Parent',guiFig);
reporter = planWorkflow.gui.PlanProgressReporter( ...
    guiFig,fill,status,details,stopButton,tabGroup);

callbackCount = 0;
reporter.setRecalculateAnalysisCallback(@recalculateAnalysis);
results = struct();
results.reference.expectedQi = struct('name','CTV','expectedValue',1);

reporter.showResults(results);

buttons = findall(guiFig,'Style','pushbutton', ...
    'Tag','planWorkflowRecalculateAnalysisButton');
verifyNumElements(testCase,buttons,1);
verifyEqual(testCase,get(buttons(1),'String'),'Recalculate analysis');
verifyEqual(testCase,get(buttons(1),'Enable'),'on');

buttonCallback = get(buttons(1),'Callback');
buttonCallback(buttons(1),[]);

verifyEqual(testCase,callbackCount,1);
messages = cellstr(get(details,'String'));
verifyTrue(testCase,any(contains(messages, ...
    'Recalculating analysis results')));

    function recalculateAnalysis()
        callbackCount = callbackCount + 1;
    end
end

function testShowResultsIncludesPerformanceTab(testCase)
guiFig = figure('Visible','off');
cleanupGui = onCleanup(@() closeFigure(guiFig));
fill = uipanel('Parent',guiFig,'Position',[0 0 0 1]);
status = uicontrol('Parent',guiFig,'Style','text');
details = uicontrol('Parent',guiFig,'Style','listbox');
stopButton = uicontrol('Parent',guiFig,'Style','pushbutton');
tabGroup = uitabgroup('Parent',guiFig);
reporter = planWorkflow.gui.PlanProgressReporter( ...
    guiFig,fill,status,details,stopButton,tabGroup);

results = struct();
results.performance = syntheticPerformanceResources();

reporter.showResults(results);

performanceTabs = findall(guiFig,'Type','uitab','Title','Performance');
verifyNumElements(testCase,performanceTabs,1);
verifyTrue(testCase,isequal(get(performanceTabs(1),'Parent'),tabGroup));

resultsTabs = findall(guiFig,'Type','uitab','Title','Results');
verifyNumElements(testCase,resultsTabs,1);
nestedPerformanceTabs = findall(resultsTabs(1),'Type','uitab', ...
    'Title','Performance');
verifyEmpty(testCase,nestedPerformanceTabs);

stageTabs = findall(performanceTabs(1),'Type','uitab','Title','Stages');
verifyNotEmpty(testCase,stageTabs);
stageTables = findall(stageTabs(1),'Type','uitable');
verifyNotEmpty(testCase,stageTables);
data = get(stageTables(1),'Data');
verifyEqual(testCase,data(1,1:3),{'Prepare','completed','1'});

planTabs = findall(performanceTabs(1),'Type','uitab','Title','Plans');
verifyNotEmpty(testCase,planTabs);
planTables = findall(planTabs(1),'Type','uitable');
verifyNotEmpty(testCase,planTables);
planData = get(planTables(1),'Data');
verifyEqual(testCase,planData(1,1:4), ...
    {'Optimize','robust','Robust interval2','fluenceOptimization'});
detailLabels = findall(planTabs(1),'Style','text','String','Detail JSON');
verifyNotEmpty(testCase,detailLabels);
detailAreas = findEditControlsContaining(planTabs(1),{'iterations: 12'});
verifyNotEmpty(testCase,detailAreas);
verifyFalse(testCase,any(contains(controlStrings(detailAreas), ...
    '{"iterations"')));

timeHelp = findall(performanceTabs(1), ...
    'Tag','planWorkflowPerformanceTimeHelp');
memoryHelp = findall(performanceTabs(1), ...
    'Tag','planWorkflowPerformanceMemoryHelp');
verifyEmpty(testCase,timeHelp);
verifyEmpty(testCase,memoryHelp);

helpPanels = findall(performanceTabs(1),'Type','uipanel', ...
    'Tag','planWorkflowPerformanceHelpPanel');
verifyEmpty(testCase,helpPanels);
tablePosition = get(stageTables(1),'Position');

helpLabels = {'Start','End','Wall time (s)','CPU time (s)', ...
    'Process start (MB)','Process end (MB)','Process delta (MB)', ...
    'Process max (MB)','Data start (MB)','Data end (MB)', ...
    'Data delta (MB)','Memory source'};
for i = 1:numel(helpLabels)
    helpText = findall(performanceTabs(1),'Style','text', ...
        'Tag',sprintf('planWorkflowPerformanceHelp%d',i));
    verifyNotEmpty(testCase,helpText);
    verifyTrue(testCase,startsWith(get(helpText(1),'String'), ...
        sprintf('%s:',helpLabels{i})));
    helpPosition = get(helpText(1),'Position');
    verifyGreaterThan(testCase,tablePosition(2), ...
        helpPosition(2) + helpPosition(4));
    verifyEqual(testCase,get(helpText(1),'FontSize'), ...
        planWorkflow.gui.TextLayout.helpTextFontSize());
    verifyEqual(testCase,get(helpText(1),'ForegroundColor'), ...
        [0.35 0.35 0.35]);
end
helpRows = planWorkflow.gui.PlanProgressReporter.performanceHelpRows();
verifyEqual(testCase,helpRows(:,1)',helpLabels);
verifyTrue(testCase,contains(helpRows{3,2},'Elapsed real time'));
verifyTrue(testCase,contains(helpRows{8,2},'Highest MATLAB process'));
end

function testSaveGuiSnapshotWritesFigInOutputFolder(testCase)
fixture = testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture);

guiFig = figure('Visible','off');
cleanupGui = onCleanup(@() closeFigure(guiFig));
fill = uipanel('Parent',guiFig,'Position',[0 0 0 1]);
status = uicontrol('Parent',guiFig,'Style','text');
details = uicontrol('Parent',guiFig,'Style','listbox');
stopButton = uicontrol('Parent',guiFig,'Style','pushbutton');
tabGroup = uitabgroup('Parent',guiFig);
reporter = planWorkflow.gui.PlanProgressReporter( ...
    guiFig,fill,status,details,stopButton,tabGroup);

filePath = reporter.saveGuiSnapshot(fixture.Folder);

verifyEqual(testCase,filePath,fullfile(fixture.Folder,'workflow_gui.fig'));
verifyTrue(testCase,isfile(filePath));
end

function resources = syntheticPerformanceResources()
resources = struct();
resources.stageTimings = struct();
resources.stageTimings.prepare = syntheticStageTiming();
resources.planTimings = syntheticPlanTiming();
end

function timing = syntheticStageTiming()
megabyte = 1024^2;
timing = struct();
timing.lastStatus = 'completed';
timing.attempts = 1;
timing.lastStartTime = '2026-05-02 10:00:00';
timing.lastEndTime = '2026-05-02 10:00:12';
timing.lastWallTimeSeconds = 12.3456;
timing.lastCpuTimeSeconds = 4.5;
timing.lastStartProcessMemoryBytes = 100 * megabyte;
timing.lastEndProcessMemoryBytes = 125 * megabyte;
timing.lastProcessMemoryDeltaBytes = 25 * megabyte;
timing.lastMaxObservedProcessMemoryBytes = 125 * megabyte;
timing.lastStartDataMemoryBytes = 8 * megabyte;
timing.lastEndDataMemoryBytes = 10 * megabyte;
timing.lastDataMemoryDeltaBytes = 2 * megabyte;
timing.memorySource = 'process_rss_ps';
end

function timing = syntheticPlanTiming()
megabyte = 1024^2;
timing = struct();
timing.stage = 'optimize';
timing.role = 'robust';
timing.label = 'Robust interval2';
timing.task = 'fluenceOptimization';
timing.robustPlanId = 'interval2';
timing.variantId = 'p1_1';
timing.status = 'completed';
timing.startTime = '2026-05-02 10:01:00';
timing.endTime = '2026-05-02 10:01:07';
timing.wallTimeSeconds = 7.25;
timing.cpuTimeSeconds = 3.125;
timing.startProcessMemoryBytes = 140 * megabyte;
timing.endProcessMemoryBytes = 170 * megabyte;
timing.processMemoryDeltaBytes = 30 * megabyte;
timing.maxObservedProcessMemoryBytes = 170 * megabyte;
timing.startDataMemoryBytes = 12 * megabyte;
timing.endDataMemoryBytes = 16 * megabyte;
timing.dataMemoryDeltaBytes = 4 * megabyte;
timing.memorySource = 'process_rss_ps';
timing.detail = '{"iterations":12}';
timing.errorMessage = '';
end

function timings = syntheticSamplingPlanTimings()
precompute = syntheticPlanTiming();
precompute.stage = 'precompute';
precompute.role = 'robust';
precompute.label = 'INTERVAL2';
precompute.task = 'robustDoseInfluence';
precompute.robustPlanId = 'interval2';
precompute.variantId = '';
precompute.wallTimeSeconds = 4.5;
precompute.cpuTimeSeconds = 2.25;
precompute.dataMemoryDeltaBytes = 3 * 1024^2;
precompute.detail = ...
    '{"dij_robust":{"numberOfScenarios":1,"matrix":{"dimensions":"1x3"}}}';

optimize = syntheticPlanTiming();
optimize.stage = 'optimize';
optimize.role = 'robust';
optimize.label = 'INTERVAL2 (theta1=5)';
optimize.task = 'fluenceOptimization';
optimize.robustPlanId = 'interval2';
optimize.variantId = 'theta_5';
optimize.wallTimeSeconds = 7.25;
optimize.cpuTimeSeconds = 3.125;
optimize.dataMemoryDeltaBytes = 4 * 1024^2;
optimize.detail = '{"iterations":12}';

timings = [precompute optimize];
end

function cstStat = samplingStructureStat(name,volumePoints)
if nargin < 2
    volumePoints = [100 90 50 0];
end
dvh = struct();
dvh.doseGrid = [0 40 60 80];
dvh.volumePoints = volumePoints;
stdDvh = struct();
stdDvh.doseGrid = dvh.doseGrid;
stdDvh.volumePoints = [0 5 10 0];

cstStat = struct();
cstStat.name = name;
cstStat.dvhStat = struct('mean',dvh,'std',stdDvh,'min',dvh,'max',dvh);
end

function titles = tabTitles(tabs)
titles = {};
for i = 1:numel(tabs)
    if isprop(tabs(i),'Title')
        titles{end + 1} = get(tabs(i),'Title'); %#ok<AGROW>
    end
end
end

function handles = findTextControlsContaining(parent,patterns)
allTextControls = findall(parent,'Style','text');
handles = gobjects(0);
for i = 1:numel(allTextControls)
    text = controlString(allTextControls(i));
    matched = true;
    for patternIx = 1:numel(patterns)
        matched = matched && ~isempty(strfind(text,patterns{patternIx})); %#ok<STREMP>
    end
    if matched
        handles(end + 1) = allTextControls(i); %#ok<AGROW>
    end
end
end

function handles = findEditControlsContaining(parent,patterns)
allEditControls = findall(parent,'Style','edit');
handles = gobjects(0);
for i = 1:numel(allEditControls)
    text = controlString(allEditControls(i));
    matched = true;
    for patternIx = 1:numel(patterns)
        matched = matched && ~isempty(strfind(text,patterns{patternIx})); %#ok<STREMP>
    end
    if matched
        handles(end + 1) = allEditControls(i); %#ok<AGROW>
    end
end
end

function text = controlString(handle)
value = get(handle,'String');
if iscell(value)
    text = strjoin(cellfun(@char,value,'UniformOutput',false),newline);
elseif isstring(value)
    text = char(strjoin(value,newline));
elseif ischar(value) && size(value,1) > 1
    text = strjoin(cellstr(value),newline);
else
    text = char(value);
end
end

function texts = controlStrings(handles)
texts = cell(numel(handles),1);
for i = 1:numel(handles)
    texts{i} = controlString(handles(i));
end
end

function touchFile(filePath)
fid = fopen(filePath,'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'placeholder');
end

function closeFigure(fig)
if ~isempty(fig) && ishghandle(fig)
    close(fig);
end
end
