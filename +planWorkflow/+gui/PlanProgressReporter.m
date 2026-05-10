classdef PlanProgressReporter < handle
    % PlanProgressReporter Updates the interactive workflow progress UI.

    properties (Access = private)
        FigureHandle
        FillHandle
        StatusHandle
        DetailHandle
        StopButtonHandle
        TabGroupHandle
        Messages = {}
        LastStageProgressLogStage = ''
        LastStageProgressLogMessage = ''
        StopRequested = false
        CurrentStageIndex = 0
        CurrentStageTotal = 1
        RecalculateAnalysisCallback = []
        RecalculateAnalysisConfigProvider = []
        RecalculateAnalysisButtonHandle = []
        IsRecalculatingAnalysis = false
        InteractiveStateStack = {}
    end

    methods
        function obj = PlanProgressReporter(fig,fill,status,details, ...
                stopButton,tabGroup)
            obj.FigureHandle = fig;
            obj.FillHandle = fill;
            obj.StatusHandle = status;
            obj.DetailHandle = details;
            if nargin >= 5
                obj.StopButtonHandle = stopButton;
                obj.setStopButtonEnabled(false);
            end
            if nargin >= 6
                obj.TabGroupHandle = tabGroup;
            end
        end

        function ready(obj)
            obj.setProgress(0,'Ready to calculate.');
        end

        function cleanupObj = beginInteractiveOperation(obj,message)
            if nargin < 2 || isempty(message)
                message = 'Working...';
            end

            if ~obj.isAvailable()
                cleanupObj = onCleanup(@() []);
                return;
            end

            obj.InteractiveStateStack{end + 1} = ...
                obj.captureInteractiveState();
            obj.showInteractiveBusy(message);
            cleanupObj = onCleanup(@() obj.endInteractiveOperation());
        end

        function calculationAccepted(obj)
            obj.StopRequested = false;
            obj.LastStageProgressLogStage = '';
            obj.LastStageProgressLogMessage = '';
            obj.setStopButtonEnabled(true);
            obj.log('Configuration accepted. Starting workflow...');
            obj.setProgress(0,'Workflow running.');
        end

        function stageStarted(obj,stageName,index,total)
            obj.CurrentStageIndex = index;
            obj.CurrentStageTotal = total;
            label = planWorkflow.config.StageConfigSchema.stageLabel(stageName);
            obj.log(sprintf('Starting %s (%d/%d).',label,index,total));
            obj.setProgress((index - 1) / total, ...
                sprintf('Running %s...',label));
        end

        function stageProgress(obj,stageName,fraction,message)
            label = planWorkflow.config.StageConfigSchema.stageLabel(stageName);
            stageFraction = max(0,min(1,double(fraction)));
            progressMessage = sprintf('%s: %s',label,char(message));
            obj.setProgress(obj.combinedStageFraction(stageFraction), ...
                progressMessage);
            obj.logStageProgress(stageName,label,message);
        end

        function stageCompleted(obj,stageName,index,total,wallTimeSeconds)
            obj.CurrentStageIndex = index;
            obj.CurrentStageTotal = total;
            label = planWorkflow.config.StageConfigSchema.stageLabel(stageName);
            obj.log(sprintf('%s completed in %.1f s.', ...
                label,wallTimeSeconds));
            obj.setProgress(index / total, ...
                sprintf('%s completed.',label));
            if index >= total
                obj.setStopButtonEnabled(false);
            end
        end

        function stageFailed(obj,stageName,index,total,message)
            label = planWorkflow.config.StageConfigSchema.stageLabel(stageName);
            obj.log(sprintf('%s failed: %s',label,char(message)));
            obj.setProgress((index - 1) / total, ...
                sprintf('%s failed.',label));
            obj.setStopButtonEnabled(false);
        end

        function requestStop(obj)
            if obj.StopRequested
                return;
            end

            obj.StopRequested = true;
            obj.setStopButtonEnabled(false);
            obj.log('Stop requested by the user.');
            obj.setProgress(obj.currentProgress(), ...
                'Stopping workflow...');
        end

        function tf = isStopRequested(obj)
            tf = obj.StopRequested;
        end

        function log(obj,message)
            if ~obj.isAvailable()
                return;
            end

            obj.Messages{end + 1} = sprintf('%s  %s', ...
                char(datetime('now','Format','HH:mm:ss')),char(message));
            if numel(obj.Messages) > 200
                obj.Messages = obj.Messages(end - 199:end);
            end

            if ishandle(obj.DetailHandle)
                obj.updateLogListbox();
            end
            obj.flushImmediate();
        end

        function setProgress(obj,fraction,message)
            if ~obj.isAvailable()
                return;
            end

            fraction = max(0,min(1,double(fraction)));
            if ishandle(obj.FillHandle)
                set(obj.FillHandle,'Position',[0 0 fraction 1]);
            end
            if ishandle(obj.StatusHandle)
                set(obj.StatusHandle,'String',sprintf('%3.0f%%  %s', ...
                    100 * fraction,char(message)));
            end
            obj.flush();
        end

        function showResults(obj,results)
            if ~obj.isAvailable() || isempty(obj.TabGroupHandle) || ...
                    ~ishandle(obj.TabGroupHandle)
                return;
            end

            obj.log('Analysis results available.');
            obj.createResultsTab(results);
        end

        function setRecalculateAnalysisCallback(obj,callback)
            if nargin < 2 || isempty(callback)
                obj.RecalculateAnalysisCallback = [];
                obj.updateRecalculateAnalysisButton();
                return;
            end

            if ~isa(callback,'function_handle')
                error('planWorkflow:gui:PlanProgressReporter:InvalidCallback', ...
                    'Recalculate analysis callback must be a function handle.');
            end

            obj.RecalculateAnalysisCallback = callback;
            obj.updateRecalculateAnalysisButton();
        end

        function setRecalculateAnalysisConfigProvider(obj,callback)
            if nargin < 2 || isempty(callback)
                obj.RecalculateAnalysisConfigProvider = [];
                return;
            end

            if ~isa(callback,'function_handle')
                error('planWorkflow:gui:PlanProgressReporter:InvalidCallback', ...
                    'Recalculate analysis config provider must be a function handle.');
            end

            obj.RecalculateAnalysisConfigProvider = callback;
        end

    end

    methods (Static)
        function entries = figureEntries(planResults)
            emptyEntry = struct('id','','label','','filePath','');
            entries = emptyEntry([]);
            if ~isstruct(planResults) || ~isfield(planResults,'figureFiles') || ...
                    ~isstruct(planResults.figureFiles)
                return;
            end

            figureFiles = planResults.figureFiles;
            figureOrder = {'gamma','robustness1','robustness2', ...
                'meanDose','stdDose','dvhMultiscenario','dvhTrustband'};
            figureLabels = {'Gamma','Robustness 1','Robustness 2', ...
                'Mean dose','Std dose','DVH multi','DVH trustband'};
            entries = repmat(emptyEntry,1,numel(figureOrder));
            entryCount = 0;
            for i = 1:numel(figureOrder)
                figureId = figureOrder{i};
                if ~isfield(figureFiles,figureId)
                    continue;
                end

                filePath = figureFiles.(figureId);
                if isstring(filePath)
                    filePath = char(filePath);
                end
                if ischar(filePath) && ~isempty(filePath) && isfile(filePath)
                    entryCount = entryCount + 1;
                    entries(entryCount) = struct( ...
                        'id',figureId, ...
                        'label',figureLabels{i}, ...
                        'filePath',filePath);
                end
            end
            entries = entries(1:entryCount);
        end

        function rows = figureTableRows(entries)
            rows = cell(numel(entries),3);
            for i = 1:numel(entries)
                [~,name,ext] = fileparts(entries(i).filePath);
                rows(i,:) = {entries(i).label,[name ext],'Open'};
            end
        end

        function folder = figureFolder(entries)
            folder = '';
            if isempty(entries)
                return;
            end

            folder = fileparts(entries(1).filePath);
        end

        function columns = performanceColumnNames()
            columns = planWorkflow.gui.PerformanceTableModel.stageColumnNames();
        end

        function columns = planPerformanceColumnNames()
            columns = planWorkflow.gui.PerformanceTableModel.planColumnNames();
        end

        function performance = resultPerformance(results)
            performance = [];
            if isstruct(results) && isfield(results,'performance')
                performance = results.performance;
                if isstruct(performance) && ...
                        isfield(performance,'planTimings') && ...
                        isstruct(performance.planTimings)
                    planTimings = ...
                        planWorkflow.performance.PrecomputeTiming.enrich( ...
                        performance.planTimings);
                    performance.planTimings = ...
                        planWorkflow.performance.OptimizationTiming.enrich( ...
                        planTimings);
                end
            end
        end

        function rows = performanceRows(resources)
            rows = planWorkflow.gui.PerformanceTableModel.stageRows(resources);
        end

        function rows = planPerformanceRows(performance)
            rows = planWorkflow.gui.PerformanceTableModel.planRows(performance);
        end

        function rows = performanceHelpRows()
            rows = { ...
                'Start', ...
                'Date and time when the stage attempt started.'; ...
                'End', ...
                'Date and time when the stage attempt finished.'; ...
                'Wall time (s)', ...
                'Elapsed real time for the stage, measured in seconds.'; ...
                'CPU time (s)', ...
                'CPU seconds consumed by the MATLAB process during the stage.'; ...
                'Process start (MB)', ...
                'MATLAB process memory at the beginning of the stage.'; ...
                'Process end (MB)', ...
                'MATLAB process memory at the end of the stage.'; ...
                'Process delta (MB)', ...
                'Process end memory minus process start memory.'; ...
                'Process max (MB)', ...
                'Highest MATLAB process memory observed during the stage.'; ...
                'Data start (MB)', ...
                'Estimated workflow data memory at the beginning of the stage.'; ...
                'Data end (MB)', ...
                'Estimated workflow data memory at the end of the stage.'; ...
                'Data delta (MB)', ...
                'Data end memory minus data start memory.'; ...
                'Memory source', ...
                'Method used to obtain process memory measurements.'};
        end

    end

    methods (Access = private)
        function tf = isAvailable(obj)
            tf = ~isempty(obj.FigureHandle) && ishandle(obj.FigureHandle);
        end

        function updateLogListbox(obj)
            messageCount = numel(obj.Messages);
            set(obj.DetailHandle,'String',obj.Messages, ...
                'Value',max(1,messageCount));

            obj.scrollLogListboxToLatest(messageCount);
        end

        function fraction = currentProgress(obj)
            fraction = 0;
            if ishandle(obj.FillHandle)
                position = get(obj.FillHandle,'Position');
                fraction = position(3);
            end
        end

        function setStopButtonEnabled(obj,enabled)
            if isempty(obj.StopButtonHandle) || ...
                    ~ishandle(obj.StopButtonHandle)
                return;
            end
            if enabled
                set(obj.StopButtonHandle,'Enable','on', ...
                    'String','Stop');
            else
                set(obj.StopButtonHandle,'Enable','off');
            end
        end

        function fraction = combinedStageFraction(obj,stageFraction)
            stageFraction = max(0,min(1,double(stageFraction)));
            fraction = (obj.CurrentStageIndex - 1 + stageFraction) / ...
                obj.CurrentStageTotal;
            fraction = max(0,min(1,fraction));
        end

        function logStageProgress(obj,stageName,label,message)
            message = strtrim(char(message));
            stageName = char(stageName);
            if isempty(message) || ...
                    (strcmp(obj.LastStageProgressLogStage,stageName) && ...
                    strcmp(obj.LastStageProgressLogMessage,message))
                return;
            end

            obj.LastStageProgressLogStage = stageName;
            obj.LastStageProgressLogMessage = message;
            obj.log(sprintf('%s: %s',label,message));
        end

        function snapshot = captureInteractiveState(obj)
            snapshot = struct('statusString','','fillPosition',[], ...
                'fillColor',[]);
            if ishandle(obj.StatusHandle)
                snapshot.statusString = get(obj.StatusHandle,'String');
            end
            if ishandle(obj.FillHandle)
                snapshot.fillPosition = get(obj.FillHandle,'Position');
                snapshot.fillColor = get(obj.FillHandle, ...
                    'BackgroundColor');
            end
        end

        function showInteractiveBusy(obj,message)
            if ~obj.isAvailable()
                return;
            end

            if ishandle(obj.FillHandle)
                position = get(obj.FillHandle,'Position');
                position(3) = max(position(3),0.02);
                set(obj.FillHandle,'Position',position, ...
                    'BackgroundColor',[0.93 0.68 0.20]);
            end
            if ishandle(obj.StatusHandle)
                set(obj.StatusHandle,'String', ...
                    sprintf('Working...  %s',char(message)));
            end
            obj.flushImmediate();
        end

        function endInteractiveOperation(obj)
            if isempty(obj.InteractiveStateStack)
                return;
            end

            snapshot = obj.InteractiveStateStack{end};
            obj.InteractiveStateStack(end) = [];
            if ~obj.isAvailable()
                return;
            end

            if ishandle(obj.StatusHandle)
                set(obj.StatusHandle,'String',snapshot.statusString);
            end
            if ishandle(obj.FillHandle)
                if ~isempty(snapshot.fillPosition)
                    set(obj.FillHandle,'Position', ...
                        snapshot.fillPosition);
                end
                if ~isempty(snapshot.fillColor)
                    set(obj.FillHandle,'BackgroundColor', ...
                        snapshot.fillColor);
                end
            end
            obj.flushImmediate();
        end

        function flush(~)
            try
                drawnow limitrate;
            catch
                drawnow;
            end
        end

        function flushImmediate(~)
            drawnow;
        end

        function scrollLogListboxToLatest(obj,messageCount)
            if messageCount < 1
                return;
            end

            minTop = max(1,messageCount - 60);
            for top = messageCount:-1:minTop
                try
                    set(obj.DetailHandle,'ListboxTop',top);
                    obj.flushImmediate();
                    if get(obj.DetailHandle,'ListboxTop') == top
                        break;
                    end
                catch
                    break;
                end
            end

            if ishandle(obj.DetailHandle)
                set(obj.DetailHandle,'Value',messageCount);
            end
        end

        function createResultsTab(obj,results)
            obj.deleteExistingResultsTab();
            resultsTab = uitab(obj.TabGroupHandle,'Title','Results');
            resultGroup = uitabgroup('Parent',resultsTab, ...
                'Units','normalized','Position',[0.02 0.10 0.96 0.87]);
            obj.RecalculateAnalysisButtonHandle = uicontrol( ...
                'Parent',resultsTab, ...
                'Style','pushbutton', ...
                'String','Recalculate analysis', ...
                'Units','normalized', ...
                'Position',[0.78 0.025 0.20 0.055], ...
                'Tag','planWorkflowRecalculateAnalysisButton', ...
                'Callback',@(~,~) obj.recalculateAnalysisFromButton());
            obj.updateRecalculateAnalysisButton();

            runConfig = struct();
            if isstruct(results) && isfield(results,'runConfig')
                runConfig = results.runConfig;
            end
            performance = ...
                planWorkflow.gui.PlanProgressReporter.resultPerformance( ...
                results);

            tabCount = 0;

            if isstruct(results) && isfield(results,'sampling')
                tabCount = tabCount + ...
                    obj.addSamplingResultTabs(resultGroup, ...
                    results.sampling,runConfig,results,performance);
            end

            if tabCount == 0
                obj.addSummaryTab(resultGroup,'Summary', ...
                    {'No analysis result entries were found.'});
            end

            obj.addPerformanceTab(obj.TabGroupHandle,results);

            try
                set(obj.TabGroupHandle,'SelectedTab',resultsTab);
            catch
            end
            obj.flush();
        end

        function deleteExistingResultsTab(obj)
            obj.deleteExistingTabByTitle('Results');
            obj.deleteExistingTabByTitle('Performance');
        end

        function deleteExistingTabByTitle(obj,titleText)
            tabs = get(obj.TabGroupHandle,'Children');
            for i = 1:numel(tabs)
                try
                    if strcmp(get(tabs(i),'Title'),titleText)
                        delete(tabs(i));
                    end
                catch
                end
            end
        end

        function recalculateAnalysisFromButton(obj)
            if obj.IsRecalculatingAnalysis
                return;
            end

            if isempty(obj.RecalculateAnalysisCallback)
                obj.log('Analysis recalculation is not available for this workflow.');
                return;
            end

            obj.IsRecalculatingAnalysis = true;
            cleanupObj = onCleanup(@() obj.finishRecalculateAnalysis());
            busyCleanup = obj.beginInteractiveOperation( ...
                'Recalculating analysis...'); %#ok<NASGU>
            obj.updateRecalculateAnalysisButton();
            obj.log('Recalculating analysis results...');
            obj.flushImmediate();

            try
                callbackArgs = {};
                if ~isempty(obj.RecalculateAnalysisConfigProvider)
                    callbackArgs = {obj.RecalculateAnalysisConfigProvider()};
                end
                obj.invokeRecalculateAnalysisCallback(callbackArgs{:});
            catch ME
                obj.log(sprintf('Analysis recalculation failed: %s', ...
                    ME.message));
                rethrow(ME);
            end
            clear busyCleanup;
        end

        function invokeRecalculateAnalysisCallback(obj,varargin)
            callbackInputCount = nargin(obj.RecalculateAnalysisCallback);
            if isempty(varargin) || callbackInputCount == 0
                obj.RecalculateAnalysisCallback();
            else
                obj.RecalculateAnalysisCallback(varargin{:});
            end
        end

        function finishRecalculateAnalysis(obj)
            obj.IsRecalculatingAnalysis = false;
            obj.updateRecalculateAnalysisButton();
        end

        function updateRecalculateAnalysisButton(obj)
            if isempty(obj.RecalculateAnalysisButtonHandle) || ...
                    ~ishandle(obj.RecalculateAnalysisButtonHandle)
                return;
            end

            if obj.IsRecalculatingAnalysis
                set(obj.RecalculateAnalysisButtonHandle, ...
                    'Enable','off', ...
                    'String','Recalculating analysis...');
            else
                enableState = 'on';
                if isempty(obj.RecalculateAnalysisCallback)
                    enableState = 'off';
                end
                set(obj.RecalculateAnalysisButtonHandle, ...
                    'Enable',enableState, ...
                    'String','Recalculate analysis');
            end
        end

        function count = addSamplingResultTabs(obj,resultGroup,sampling, ...
                runConfig,results,performance)
            if nargin < 5
                results = struct();
            end
            if nargin < 6
                performance = [];
            end

            count = 0;
            if isstruct(sampling) && isfield(sampling,'reference')
                options = struct();
                options.performance = performance;
                options.planIdentity = obj.referencePlanIdentity();
                options.embeddedPlanResults = obj.referenceResults(results);
                options.embeddedReferencePlanResults = ...
                    options.embeddedPlanResults;
                count = count + 1;
                obj.addAnalysisResultTab(resultGroup, ...
                    obj.samplingReferenceTabTitle(sampling.reference,runConfig), ...
                    sampling.reference,runConfig,false,'Expected QI', ...
                    sampling.reference,options);
            end

            if isstruct(sampling) && isfield(sampling,'robust')
                for i = 1:numel(sampling.robust)
                    titleText = obj.samplingRobustTabTitle( ...
                        sampling.robust{i},runConfig,i);
                    options = struct();
                    options.performance = performance;
                    options.planIdentity = obj.samplingRobustPlanIdentity( ...
                        sampling.robust{i},runConfig,i);
                    options.embeddedPlanResults = obj.robustResult(results,i);
                    options.embeddedReferencePlanResults = ...
                        obj.referenceResults(results);
                    count = count + 1;
                    obj.addAnalysisResultTab(resultGroup, ...
                        titleText,sampling.robust{i},runConfig,false, ...
                        'Expected QI',obj.referenceSamplingResults(sampling), ...
                        options);
                end
            end
        end

        function titleText = samplingReferenceTabTitle(obj,planResults, ...
                runConfig) %#ok<INUSD>
            titleText = 'Reference';
            if isstruct(planResults) && isfield(planResults,'label') && ...
                    ~isempty(planResults.label)
                titleText = char(planResults.label);
                return;
            end
            if isstruct(runConfig) && isfield(runConfig,'reference_label') && ...
                    ~isempty(runConfig.reference_label)
                referenceLabel = strtrim(char(runConfig.reference_label));
                if ~isempty(referenceLabel)
                    titleText = sprintf('Reference (%s)',referenceLabel);
                end
            end
        end

        function titleText = samplingRobustTabTitle(obj,planResults, ...
                runConfig,resultIx) %#ok<INUSD>
            label = sprintf('robust %d',resultIx);
            if isstruct(planResults) && isfield(planResults,'label') && ...
                    ~isempty(planResults.label)
                label = char(planResults.label);
            end
            label = planWorkflow.results.PlanLabels.robustResultLabelFromRunConfig( ...
                runConfig,resultIx,label);
            titleText = label;
        end

        function addAnalysisResultTab(obj,resultGroup,titleText,planResults, ...
                runConfig,showDetailTable,detailTabTitle,referencePlanResults, ...
                options)
            if nargin < 6
                showDetailTable = true;
            end
            if nargin < 7
                detailTabTitle = '';
            end
            if nargin < 8
                referencePlanResults = [];
            end
            if nargin < 9
                options = struct();
            end

            tab = uitab(resultGroup,'Title',titleText);
            uicontrol('Parent',tab,'Style','text','String',titleText, ...
                'Units','normalized','Position',[0.03 0.92 0.94 0.05], ...
                'FontWeight','bold','HorizontalAlignment','left');

            figureEntries = ...
                planWorkflow.gui.PlanProgressReporter.figureEntries( ...
                planResults);
            summaryRows = obj.summaryRows( ...
                planResults,runConfig,referencePlanResults, ...
                obj.optionValue(options,'performance',[]), ...
                obj.optionValue(options,'planIdentity',struct()));
            qiSource = obj.qiSource(planResults);
            showSeparateDetailTab = ~showDetailTable && ...
                ~isempty(detailTabTitle) && ~isempty(qiSource);
            clinicalRows = obj.clinicalRows( ...
                planResults,runConfig,referencePlanResults);
            showSeparateClinicalTab = ~showDetailTable && ...
                ~isempty(clinicalRows);
            showSamplingSummaryPanel = ~showDetailTable && ...
                ~isempty(summaryRows);
            embeddedPlanResults = obj.optionValue( ...
                options,'embeddedPlanResults',[]);
            showEmbeddedResultsTab = ~showDetailTable && ...
                isstruct(embeddedPlanResults);
            if ~isempty(figureEntries) || showSeparateDetailTab || ...
                    showSeparateClinicalTab || showSamplingSummaryPanel || ...
                    showEmbeddedResultsTab
                contentGroup = uitabgroup('Parent',tab, ...
                    'Units','normalized','Position',[0.03 0.05 0.94 0.84]);
                summaryTab = uitab(contentGroup,'Title','Summary');
                if showDetailTable
                    obj.addAnalysisTables( ...
                        summaryTab,planResults,runConfig,true, ...
                        showDetailTable,false,referencePlanResults);
                else
                    obj.addSummaryPanel(summaryTab,summaryRows,true);
                end
                if showEmbeddedResultsTab
                    obj.addPlanResultsTab(contentGroup,'Nominal QI', ...
                        embeddedPlanResults,runConfig, ...
                        obj.optionValue(options, ...
                        'embeddedReferencePlanResults',[]));
                end
                if showSeparateDetailTab
                    obj.addQiTableTab(contentGroup,detailTabTitle, ...
                        planResults);
                end
                if showSeparateClinicalTab
                    obj.addClinicalTableTab(contentGroup, ...
                        'Clinical endpoints',clinicalRows);
                end
                if ~isempty(figureEntries)
                    if showDetailTable
                        obj.addFiguresTableTab(contentGroup,figureEntries);
                    else
                        obj.addFiguresPanelTab(contentGroup,figureEntries);
                    end
                end
                return;
            end

            hasContent = obj.addAnalysisTables( ...
                tab,planResults,runConfig,false,showDetailTable, ...
                true,referencePlanResults);
            if ~hasContent
                obj.addSummaryTab(resultGroup,titleText, ...
                    {'No tabular analysis data available.'});
                delete(tab);
            end
        end

        function hasContent = addAnalysisTables(obj,parent,planResults, ...
                runConfig,showEmptyMessage,showDetailTable, ...
                showClinicalTable,referencePlanResults)
            if nargin < 6
                showDetailTable = true;
            end
            if nargin < 7
                showClinicalTable = true;
            end
            if nargin < 8
                referencePlanResults = [];
            end

            hasContent = false;
            summaryRows = obj.summaryRows( ...
                planResults,runConfig,referencePlanResults);
            if ~isempty(summaryRows)
                summaryHeight = 0.18;
                uitable('Parent',parent,'Units','normalized', ...
                    'Position',[0.03 0.74 0.94 summaryHeight], ...
                    'ColumnName',{'Metric','Value'}, ...
                    'ColumnEditable',[false false], ...
                    'ColumnWidth',{220 520}, ...
                    'Data',summaryRows(:,1:2));
                hasContent = true;
            end

            qiSource = obj.qiSource(planResults);
            if showDetailTable && ~isempty(qiSource)
                qiRows = obj.qiRows(qiSource,planResults);
                bottom = 0.05;
                height = 0.65;
                if isempty(summaryRows)
                    height = 0.82;
                end
                uitable('Parent',parent,'Units','normalized', ...
                    'Position',[0.03 bottom 0.94 height], ...
                    'ColumnName',obj.qiColumnNames(), ...
                    'ColumnEditable',false(1,numel(obj.qiColumnNames())), ...
                    'Data',qiRows);
                hasContent = true;
                return;
            end

            if showClinicalTable
                clinicalRows = obj.clinicalRows( ...
                    planResults,runConfig,referencePlanResults);
            else
                clinicalRows = {};
            end
            if ~isempty(clinicalRows)
                uitable('Parent',parent,'Units','normalized', ...
                    'Position',[0.03 0.05 0.94 0.65], ...
                    'ColumnName',obj.clinicalColumnNames(), ...
                    'ColumnEditable',false(1,numel(obj.clinicalColumnNames())), ...
                    'Data',clinicalRows);
                hasContent = true;
                return;
            end

            if ~hasContent && showEmptyMessage
                uicontrol('Parent',parent,'Style','listbox', ...
                    'String',{'No tabular analysis data available.'}, ...
                    'Units','normalized','Position',[0.03 0.05 0.94 0.90]);
            end
        end

        function addQiTableTab(obj,resultGroup,titleText,planResults)
            qiSource = obj.qiSource(planResults);
            if isempty(qiSource)
                return;
            end

            tab = uitab(resultGroup,'Title',titleText);
            uitable('Parent',tab,'Units','normalized', ...
                'Position',[0.03 0.05 0.94 0.90], ...
                'ColumnName',obj.qiColumnNames(), ...
                'ColumnEditable',false(1,numel(obj.qiColumnNames())), ...
                'Data',obj.qiRows(qiSource,planResults));
        end

        function addPlanResultsTab(obj,resultGroup,titleText,planResults, ...
                ~,~)
            qiSource = obj.qiSource(planResults);
            if isempty(qiSource)
                return;
            end

            tab = uitab(resultGroup,'Title',titleText);
            uitable('Parent',tab,'Units','normalized', ...
                'Position',[0.03 0.05 0.94 0.90], ...
                'ColumnName',obj.qiColumnNames(), ...
                'ColumnEditable',false(1,numel(obj.qiColumnNames())), ...
                'Data',obj.qiRows(qiSource,planResults));
        end

        function addClinicalTableTab(obj,resultGroup,titleText,clinicalRows)
            tab = uitab(resultGroup,'Title',titleText);
            uitable('Parent',tab,'Units','normalized', ...
                'Position',[0.03 0.05 0.94 0.90], ...
                'ColumnName',obj.clinicalColumnNames(), ...
                'ColumnEditable',false(1,numel(obj.clinicalColumnNames())), ...
                'Data',clinicalRows);
        end

        function addSummaryPanel(obj,parent,summaryRows,showEmptyMessage)
            if isempty(summaryRows)
                if showEmptyMessage
                    uicontrol('Parent',parent,'Style','listbox', ...
                        'String',{'No summary data available.'}, ...
                        'Units','normalized', ...
                        'Position',[0.03 0.05 0.94 0.90]);
                end
                return;
            end

            panel = obj.createReadOnlyPanel(parent, ...
                'planWorkflowSamplingSummaryPanel');
            obj.addPanelRows(panel,summaryRows,'');
        end

        function addFiguresTableTab(obj,resultGroup,entries)
            tab = uitab(resultGroup,'Title','Figures');
            figureFolder = ...
                planWorkflow.gui.PlanProgressReporter.figureFolder(entries);
            uicontrol('Parent',tab,'Style','text','String','Folder', ...
                'Units','normalized','Position',[0.03 0.90 0.08 0.05], ...
                'HorizontalAlignment','left');
            uicontrol('Parent',tab,'Style','edit','String',figureFolder, ...
                'Units','normalized','Position',[0.12 0.90 0.74 0.05], ...
                'HorizontalAlignment','left','Enable','inactive');
            uicontrol('Parent',tab,'Style','pushbutton','String','Open', ...
                'Units','normalized','Position',[0.87 0.90 0.10 0.05], ...
                'Callback',@(~,~) obj.openFigureFolder(figureFolder));
            uitable('Parent',tab,'Units','normalized', ...
                'Position',[0.03 0.05 0.94 0.80], ...
                'ColumnName',{'Figure','File','Action'}, ...
                'ColumnEditable',false(1,3), ...
                'ColumnWidth',{160 360 80}, ...
                'Data',planWorkflow.gui.PlanProgressReporter.figureTableRows( ...
                entries), ...
                'CellSelectionCallback', ...
                @(src,event) obj.openFigureFromTable(src,event,entries));
        end

        function addFiguresPanelTab(obj,resultGroup,entries)
            tab = uitab(resultGroup,'Title','Figures');
            panel = obj.createReadOnlyPanel(tab, ...
                'planWorkflowSamplingFiguresPanel');
            figureFolder = ...
                planWorkflow.gui.PlanProgressReporter.figureFolder(entries);
            rowControls = gobjects(0);
            y = 0.93;
            [controls,rowHeight] = obj.addPanelRow(panel,1,y, ...
                'Folder',figureFolder,'Open', ...
                @(~,~) obj.openFigureFolder(figureFolder),'');
            rowControls = [rowControls controls(:)'];
            y = y - obj.panelRowStride(rowHeight);

            for i = 1:numel(entries)
                [~,name,ext] = fileparts(entries(i).filePath);
                [controls,rowHeight] = obj.addPanelRow(panel,i + 1,y, ...
                    entries(i).label, ...
                    [name ext],'Open', ...
                    @(~,~) obj.openFigureFile(entries(i).filePath),'');
                rowControls = [rowControls controls(:)']; %#ok<AGROW>
                y = y - obj.panelRowStride(rowHeight);
            end

            scrollSlider = planWorkflow.gui.PanelScroller.panelSlider(panel);
            if ~isempty(scrollSlider)
                planWorkflow.gui.PanelScroller.configure( ...
                    scrollSlider,rowControls,y);
            end
        end

        function added = addPerformanceTab(obj,parentGroup,results)
            performance = ...
                planWorkflow.gui.PlanProgressReporter.resultPerformance( ...
                results);

            stageRows = ...
                planWorkflow.gui.PlanProgressReporter.performanceRows( ...
                performance);
            planRows = ...
                planWorkflow.gui.PlanProgressReporter.planPerformanceRows( ...
                performance);
            added = ~isempty(stageRows) || ~isempty(planRows);
            if ~added
                return;
            end

            tab = uitab(parentGroup,'Title','Performance');
            performanceGroup = uitabgroup('Parent',tab, ...
                'Units','normalized','Position',[0.03 0.05 0.94 0.90]);

            if ~isempty(stageRows)
                stageTab = uitab(performanceGroup,'Title','Stages');
                uitable('Parent',stageTab,'Units','normalized', ...
                    'Position',[0.03 0.43 0.94 0.52], ...
                    'ColumnName', ...
                    planWorkflow.gui.PlanProgressReporter.performanceColumnNames(), ...
                    'ColumnEditable', ...
                    false(1,numel( ...
                    planWorkflow.gui.PlanProgressReporter.performanceColumnNames())), ...
                    'ColumnWidth',{110 90 70 135 135 100 100 120 120 120 ...
                    120 110 110 110 150}, ...
                    'Data',stageRows);
                obj.addPerformanceHelpText(stageTab, ...
                    planWorkflow.gui.PlanProgressReporter.performanceHelpRows());
            end

            if ~isempty(planRows)
                planTab = uitab(performanceGroup,'Title','Plans');
                detailLabel = uicontrol('Parent',planTab, ...
                    'Style','text','String','Detail JSON', ...
                    'Units','normalized', ...
                    'Position',[0.03 0.35 0.94 0.04], ...
                    'HorizontalAlignment','left','FontWeight','bold');
                detailText = uicontrol('Parent',planTab, ...
                    'Style','edit','Max',2,'Min',0, ...
                    'String',{''}, ...
                    'Units','normalized', ...
                    'Position',[0.03 0.05 0.94 0.29], ...
                    'HorizontalAlignment','left','Enable','inactive', ...
                    'BackgroundColor',[1 1 1]);
                planTable = uitable('Parent',planTab,'Units','normalized', ...
                    'Position',[0.03 0.43 0.94 0.52], ...
                    'ColumnName', ...
                    planWorkflow.gui.PlanProgressReporter.planPerformanceColumnNames(), ...
                    'ColumnEditable',false(1,numel( ...
                    planWorkflow.gui.PlanProgressReporter.planPerformanceColumnNames())), ...
                    'ColumnWidth',{110 80 150 160 100 90 135 135 100 100 ...
                    120 120 110 150 420 220}, ...
                    'CellSelectionCallback', ...
                    @(src,event) obj.updatePlanPerformanceDetail( ...
                    src,event,detailText), ...
                    'Data',planRows);
                obj.updatePlanPerformanceDetailForRow( ...
                    planTable,1,detailText);
                set(detailLabel,'TooltipString', ...
                    'Formatted Detail JSON for the selected plan task.');
            end
        end

        function addPerformanceHelpText(~,parent,rows)
            helpY = 0.37;
            rowHeight = 0.024;
            rowStride = 0.027;
            for i = 1:size(rows,1)
                text = sprintf('%s: %s',rows{i,1},rows{i,2});
                uicontrol('Parent',parent,'Style','text', ...
                    'String',text, ...
                    'HorizontalAlignment','left','Units','normalized', ...
                    'Position',[0.03 helpY 0.94 rowHeight], ...
                    'FontSize', ...
                    planWorkflow.gui.TextLayout.helpTextFontSize(), ...
                    'ForegroundColor',[0.35 0.35 0.35], ...
                    'Tag',sprintf('planWorkflowPerformanceHelp%d',i));
                helpY = helpY - rowStride;
            end
        end

        function openFigureFromTable(~,~,event,entries)
            if isempty(event.Indices) || size(event.Indices,2) < 2 || ...
                    event.Indices(2) ~= 3
                return;
            end

            row = event.Indices(1);
            if row < 1 || row > numel(entries)
                return;
            end

            filePath = entries(row).filePath;
            try
                openfig(filePath,'new','visible');
            catch ME
                errordlg(sprintf('Could not open figure "%s": %s', ...
                    filePath,ME.message),'Open figure');
            end
        end

        function openFigureFile(~,filePath)
            try
                openfig(filePath,'new','visible');
            catch ME
                errordlg(sprintf('Could not open figure "%s": %s', ...
                    filePath,ME.message),'Open figure');
            end
        end

        function openFigureFolder(~,folderPath)
            if isempty(folderPath) || ~isfolder(folderPath)
                errordlg(sprintf('Could not open folder "%s".', ...
                    folderPath),'Open folder');
                return;
            end

            try
                if ispc
                    winopen(folderPath);
                elseif ismac
                    system(sprintf('open "%s"',strrep(folderPath,'"','\"')));
                else
                    system(sprintf('xdg-open "%s" &', ...
                        strrep(folderPath,'"','\"')));
                end
            catch ME
                errordlg(sprintf('Could not open folder "%s": %s', ...
                    folderPath,ME.message),'Open folder');
            end
        end

        function addSummaryTab(~,resultGroup,titleText,messages)
            tab = uitab(resultGroup,'Title',titleText);
            uicontrol('Parent',tab,'Style','listbox','String',messages, ...
                'Units','normalized','Position',[0.03 0.05 0.94 0.90]);
        end

        function panel = createReadOnlyPanel(~,parent,tag,position)
            if nargin < 4
                position = [0.03 0.05 0.94 0.90];
            end

            panel = uipanel('Parent',parent,'Units','normalized', ...
                'Position',position, ...
                'BorderType','line','BackgroundColor',[1 1 1], ...
                'Tag',tag);
            planWorkflow.gui.PanelScroller.createSlider(panel);
        end

        function addPanelRows(obj,panel,rows,tagPrefix)
            rowControls = gobjects(0);
            y = 0.93;
            contentBottom = y;
            for i = 1:size(rows,1)
                rowType = '';
                if size(rows,2) >= 3
                    rowType = char(rows{i,3});
                end
                helpText = '';
                if size(rows,2) >= 4
                    helpText = char(rows{i,4});
                end
                switch rowType
                    case 'section'
                        [controls,rowHeight] = obj.addPanelSection( ...
                            panel,i,y,rows{i,1},tagPrefix,helpText);
                    case 'fieldHelp'
                        [controls,rowHeight] = obj.addPanelRow(panel,i,y, ...
                            rows{i,1},rows{i,2},'',[],tagPrefix, ...
                            helpText,true);
                    case 'json'
                        [controls,rowHeight] = obj.addPanelJsonRow( ...
                            panel,i,y,rows{i,1},rows{i,2}, ...
                            tagPrefix,helpText);
                    case 'help'
                        [controls,rowHeight] = obj.addPanelHelp( ...
                            panel,i,y,rows{i,1},tagPrefix);
                    otherwise
                        [controls,rowHeight] = obj.addPanelRow(panel,i,y,rows{i,1}, ...
                            rows{i,2},'',[],tagPrefix,helpText);
                end
                rowControls = [rowControls controls(:)']; %#ok<AGROW>
                y = y - obj.panelRowStride(rowHeight);
                contentBottom = min(contentBottom,y);
            end

            scrollSlider = planWorkflow.gui.PanelScroller.panelSlider(panel);
            if ~isempty(scrollSlider)
                planWorkflow.gui.PanelScroller.configure( ...
                    scrollSlider,rowControls,contentBottom);
            end
        end

        function [controls,rowHeight] = addPanelJsonRow(obj,panel,rowIndex,y, ...
                label,value,tagPrefix,helpText)
            labelHeight = 0.045;
            gap = 0.012;
            lines = obj.jsonDisplayLines(value);
            editHeight = min(0.34,max(0.12,0.025*numel(lines) + 0.030));
            rowHeight = labelHeight + gap + editHeight;

            if nargin < 7
                tagPrefix = '';
            end
            if nargin < 8
                helpText = '';
            end

            labelTag = '';
            valueTag = '';
            if ~isempty(tagPrefix)
                labelTag = sprintf('%sJsonLabel%d',tagPrefix,rowIndex);
                valueTag = sprintf('%sJsonValue%d',tagPrefix,rowIndex);
            end

            labelControl = uicontrol('Parent',panel,'Style','text', ...
                'String',char(label),'Units','normalized', ...
                'Position',[0.02 y 0.94 labelHeight], ...
                'HorizontalAlignment','left','FontWeight','bold', ...
                'BackgroundColor',[1 1 1], ...
                'TooltipString',helpText, ...
                'Tag',labelTag);
            valueControl = uicontrol('Parent',panel,'Style','edit', ...
                'Max',2,'Min',0, ...
                'String',lines,'Units','normalized', ...
                'Position',[0.02 y - gap - editHeight 0.94 editHeight], ...
                'HorizontalAlignment','left','Enable','inactive', ...
                'BackgroundColor',[1 1 1], ...
                'TooltipString','', ...
                'Tag',valueTag);
            controls = [labelControl valueControl];
        end

        function [controls,rowHeight] = addPanelSection(~,panel,rowIndex,y,label, ...
                tagPrefix,helpText)
            rowHeight = 0.045;

            if nargin < 6
                tagPrefix = '';
            end
            if nargin < 7
                helpText = '';
            end

            labelTag = '';
            if ~isempty(tagPrefix)
                labelTag = sprintf('%sSection%d',tagPrefix,rowIndex);
            end

            controls = uicontrol('Parent',panel,'Style','text', ...
                'String',char(label),'Units','normalized', ...
                'Position',[0.02 y 0.94 rowHeight], ...
                'HorizontalAlignment','left','FontWeight','bold', ...
                'BackgroundColor',[0.94 0.94 0.94], ...
                'TooltipString',helpText, ...
                'Tag',labelTag);
        end

        function [controls,rowHeight] = addPanelHelp(~,panel,rowIndex,y,text,tagPrefix)
            wrapColumn = planWorkflow.gui.TextLayout.wideHelpTextWrapColumn();
            displayText = planWorkflow.gui.TextLayout.helpTextForDisplay( ...
                text,wrapColumn);
            rowHeight = max(0.060, ...
                planWorkflow.gui.TextLayout.helpTextHeightForDisplay( ...
                displayText,wrapColumn));

            if nargin < 6
                tagPrefix = '';
            end

            helpTag = '';
            if ~isempty(tagPrefix)
                helpTag = sprintf('%sHelp%d',tagPrefix,rowIndex);
            end

            controls = uicontrol('Parent',panel,'Style','text', ...
                'String',displayText,'Units','normalized', ...
                'Position',[0.02 y 0.94 rowHeight], ...
                'HorizontalAlignment','left', ...
                'FontSize',planWorkflow.gui.TextLayout.helpTextFontSize(), ...
                'ForegroundColor',[0.35 0.35 0.35], ...
                'BackgroundColor',[1 1 1], ...
                'TooltipString',char(text), ...
                'Tag',helpTag);
        end

        function [controls,rowHeight] = addPanelRow(~,panel,rowIndex,y, ...
                label,value,buttonText, ...
                callback,tagPrefix,helpText,showInlineHelp)
            controlHeight = 0.050;
            rowHeight = controlHeight;

            if nargin < 9
                tagPrefix = '';
            end
            if nargin < 10
                helpText = '';
            end
            if nargin < 11
                showInlineHelp = false;
            end
            labelTooltip = helpText;
            valueTooltip = char(string(value));
            if ~isempty(helpText) && ~showInlineHelp
                valueTooltip = helpText;
            end
            if showInlineHelp
                labelTooltip = '';
            end

            labelTag = '';
            valueTag = '';
            noteTag = '';
            if ~isempty(tagPrefix)
                labelTag = sprintf('%sLabel%d',tagPrefix,rowIndex);
                valueTag = sprintf('%sValue%d',tagPrefix,rowIndex);
                noteTag = sprintf('%sNote%d',tagPrefix,rowIndex);
            end

            labelControl = uicontrol('Parent',panel,'Style','text', ...
                'String',char(label),'Units','normalized', ...
                'Position',[0.02 y 0.27 controlHeight], ...
                'HorizontalAlignment','left','FontWeight','bold', ...
                'BackgroundColor',[1 1 1], ...
                'TooltipString',labelTooltip, ...
                'Tag',labelTag);
            valueWidth = 0.64;
            if ~isempty(buttonText)
                valueWidth = 0.52;
            end
            valueControl = uicontrol('Parent',panel,'Style','edit', ...
                'String',char(string(value)),'Units','normalized', ...
                'Position',[0.32 y 0.64 controlHeight], ...
                'HorizontalAlignment','left','Enable','inactive', ...
                'BackgroundColor',[1 1 1], ...
                'TooltipString',valueTooltip, ...
                'Tag',valueTag);
            controls = [labelControl valueControl];
            if showInlineHelp && ~isempty(char(helpText))
                displayText = planWorkflow.gui.TextLayout.helpTextForDisplay( ...
                    helpText, ...
                    planWorkflow.gui.TextLayout.parameterHelpTextWrapColumn());
                noteHeight = ...
                    planWorkflow.gui.TextLayout.helpTextHeightForDisplay( ...
                    displayText, ...
                    planWorkflow.gui.TextLayout.parameterHelpTextWrapColumn());
                noteControl = uicontrol('Parent',panel,'Style','text', ...
                    'String',displayText, ...
                    'Units','normalized', ...
                    'Position',[0.02 y - noteHeight ...
                    planWorkflow.gui.TextLayout.helpTextWidth() ...
                    noteHeight], ...
                    'HorizontalAlignment','left', ...
                    'FontSize', ...
                    planWorkflow.gui.TextLayout.helpTextFontSize(), ...
                    'ForegroundColor',[0.35 0.35 0.35], ...
                    'BackgroundColor',[1 1 1], ...
                    'TooltipString','', ...
                    'Tag',noteTag);
                controls = [controls noteControl];
                rowHeight = rowHeight + noteHeight;
            end
            if ~isempty(buttonText)
                set(valueControl,'Position',[0.32 y valueWidth controlHeight]);
                buttonControl = uicontrol('Parent',panel,'Style','pushbutton', ...
                    'String',buttonText,'Units','normalized', ...
                    'Position',[0.86 y 0.10 controlHeight], ...
                    'Callback',callback);
                controls = [controls buttonControl];
            end
        end

        function stride = panelRowStride(~,rowHeight)
            stride = max(0.075,rowHeight + 0.020);
        end

        function rows = summaryRows(obj,planResults,runConfig, ...
                referencePlanResults,performance,planIdentity)
            if nargin < 3
                runConfig = struct();
            end
            if nargin < 4
                referencePlanResults = [];
            end
            if nargin < 5
                performance = [];
            end
            if nargin < 6
                planIdentity = struct();
            end

            rows = {};
            if ~isstruct(planResults)
                rows = {'Value',obj.valueText(planResults),'',''};
                return;
            end

            evaluationRows = obj.evaluationParameterSummaryRows( ...
                planResults);
            if ~isempty(evaluationRows)
                rows(end + 1,:) = {'Evaluation parameters','', ...
                    'section',''};
                rows = [rows; evaluationRows];
            end

            gammaRows = obj.gammaSummaryRows(planResults,runConfig);
            if ~isempty(gammaRows)
                rows(end + 1,:) = {'Gamma','','section',''};
                rows = [rows; gammaRows];
            end

            robustnessRows = obj.robustnessSummaryRows(planResults);
            if ~isempty(robustnessRows)
                riHelpText = obj.robustnessIndexHelpText('all');
                rows(end + 1,:) = {'Robustness','', ...
                    'section',riHelpText};
                rows(end + 1,:) = {'Targets', ...
                    obj.robustnessTargetsText(runConfig),'', ...
                    'Structures included in the robustness index calculation.'};
                rows = [rows; robustnessRows];
            end

            porRows = obj.priceOfRobustnessSummaryRows( ...
                planResults,runConfig,referencePlanResults);
            if ~isempty(porRows)
                rows(end + 1,:) = {'Price of Robustness','', ...
                    'section',''};
                rows = [rows; porRows];
            end

            performanceRows = obj.planPerformanceSummaryRows( ...
                performance,planIdentity);
            if ~isempty(performanceRows)
                rows(end + 1,:) = {'Performance','','section', ...
                    'Performance timings and task detail JSON for this plan.'};
                rows = [rows; performanceRows];
            end
        end

        function rows = evaluationParameterSummaryRows(obj,planResults)
            rows = {};
            fields = {'evaluationMode','evaluationModeBase', ...
                'evaluationScale'};
            labels = {'Evaluation mode','Evaluation mode base', ...
                'Evaluation scale'};
            for i = 1:numel(fields)
                if isfield(planResults,fields{i})
                    rows(end + 1,:) = {labels{i}, ...
                        obj.valueText(planResults.(fields{i})),'',''}; %#ok<AGROW>
                end
            end
        end

        function rows = planPerformanceSummaryRows(obj,performance,planIdentity)
            rows = {};
            if ~isstruct(performance) || ...
                    ~isfield(performance,'planTimings') || ...
                    ~isstruct(performance.planTimings) || ...
                    ~isstruct(planIdentity) || ...
                    ~isfield(planIdentity,'role')
                return;
            end

            stageNames = {'precompute','optimize'};
            for stageIx = 1:numel(stageNames)
                timings = obj.matchingPlanTimings( ...
                    performance.planTimings,planIdentity,stageNames{stageIx});
                summary = obj.aggregatePlanTimings(timings);
                if summary.count == 0
                    continue;
                end

                label = planWorkflow.config.StageConfigSchema.stageLabel( ...
                    stageNames{stageIx});
                rows(end + 1,:) = {[label ' wall time (s)'], ...
                    planWorkflow.gui.ValueFormat.seconds( ...
                    summary.wallTimeSeconds),'', ...
                    'Elapsed real time measured for this plan stage.'}; %#ok<AGROW>
                rows(end + 1,:) = {[label ' CPU time (s)'], ...
                    planWorkflow.gui.ValueFormat.seconds( ...
                    summary.cpuTimeSeconds),'', ...
                    'CPU seconds consumed by MATLAB for this plan stage.'}; %#ok<AGROW>
                if strcmp(stageNames{stageIx},'precompute')
                    dijTiming = obj.dijPrecomputeTiming(timings);
                    if ~isempty(dijTiming)
                        rows = obj.appendDijPrecomputeTimingRows( ...
                            rows,dijTiming);
                    end
                end
                if strcmp(stageNames{stageIx},'optimize')
                    optimizationTiming = obj.fluenceOptimizationTiming( ...
                        timings);
                    if ~isempty(optimizationTiming)
                        rows = obj.appendOptimizationTimingRows( ...
                            rows,optimizationTiming);
                    end
                end
                rows(end + 1,:) = {[label ' Detail JSON'], ...
                    summary.detailJson,'json', ...
                    'Task detail JSON recorded for this plan stage.'}; %#ok<AGROW>
            end
        end

        function updatePlanPerformanceDetail(obj,tableHandle,event, ...
                detailTextHandle)
            if isempty(event.Indices)
                return;
            end

            obj.updatePlanPerformanceDetailForRow( ...
                tableHandle,event.Indices(1),detailTextHandle);
        end

        function updatePlanPerformanceDetailForRow(obj,tableHandle,row, ...
                detailTextHandle)
            if isempty(tableHandle) || ~ishandle(tableHandle) || ...
                    isempty(detailTextHandle) || ~ishandle(detailTextHandle)
                return;
            end

            data = get(tableHandle,'Data');
            if isempty(data) || row < 1 || row > size(data,1)
                set(detailTextHandle,'String',{'No detail JSON selected.'});
                return;
            end

            columns = get(tableHandle,'ColumnName');
            detailCol = find(strcmp(columns,'Detail JSON'),1,'first');
            if isempty(detailCol) || detailCol > size(data,2)
                set(detailTextHandle,'String',{'No Detail JSON column.'});
                return;
            end

            detailText = data{row,detailCol};
            set(detailTextHandle,'String',obj.jsonDisplayLines(detailText));
        end

        function timings = matchingPlanTimings(obj,planTimings,planIdentity, ...
                stageName) %#ok<INUSD>
            timings = planTimings([]);
            for i = 1:numel(planTimings)
                timing = planTimings(i);
                if ~isstruct(timing) || ~isfield(timing,'stage') || ...
                        ~strcmp(char(timing.stage),stageName)
                    continue;
                end
                if ~isfield(timing,'role') || ...
                        ~strcmp(char(timing.role),char(planIdentity.role))
                    continue;
                end

                if strcmp(char(planIdentity.role),'robust')
                    if ~isfield(planIdentity,'robustPlanId') || ...
                            isempty(planIdentity.robustPlanId) || ...
                            ~isfield(timing,'robustPlanId') || ...
                            ~strcmp(char(timing.robustPlanId), ...
                            char(planIdentity.robustPlanId))
                        continue;
                    end
                    if strcmp(stageName,'optimize') && ...
                            isfield(planIdentity,'variantId') && ...
                            ~isempty(planIdentity.variantId)
                        if ~isfield(timing,'variantId') || ...
                                ~strcmp(char(timing.variantId), ...
                                char(planIdentity.variantId))
                            continue;
                        end
                    end
                end

                timings(end + 1) = timing; %#ok<AGROW>
            end
        end

        function summary = aggregatePlanTimings(obj,timings)
            summary = struct();
            summary.count = 0;
            summary.wallTimeSeconds = 0;
            summary.cpuTimeSeconds = 0;
            summary.detailJson = '{}';

            detailEntries = struct('task',{},'variantId',{},'detail',{});
            for i = 1:numel(timings)
                timing = timings(i);
                summary.count = summary.count + 1;
                summary.wallTimeSeconds = summary.wallTimeSeconds + ...
                    obj.numericTimingValue(timing,'wallTimeSeconds',0);
                summary.cpuTimeSeconds = summary.cpuTimeSeconds + ...
                    obj.numericTimingValue(timing,'cpuTimeSeconds',0);
                detailText = obj.timingDetailText(timing);
                if ~isempty(detailText)
                    detailEntry = struct();
                    detailEntry.task = char(obj.timingValue( ...
                        timing,'task',''));
                    detailEntry.variantId = char(obj.timingValue( ...
                        timing,'variantId',''));
                    detailEntry.detail = obj.parseDetailJson(detailText);
                    detailEntries(end + 1) = detailEntry; %#ok<AGROW>
                end
            end
            if ~isempty(detailEntries)
                summary.detailJson = jsonencode(struct('tasks',detailEntries));
            end
        end

        function timing = fluenceOptimizationTiming(~,timings)
            timing = [];
            for i = 1:numel(timings)
                candidate = timings(i);
                if isstruct(candidate) && isfield(candidate,'task') && ...
                        strcmp(char(candidate.task),'fluenceOptimization')
                    timing = candidate;
                end
            end
        end

        function timing = dijPrecomputeTiming(obj,timings)
            timing = [];
            for i = 1:numel(timings)
                candidate = timings(i);
                if obj.isFiniteTimingValue( ...
                        candidate,'dijPrecomputingTimeSeconds')
                    timing = candidate;
                end
            end
        end

        function rows = appendDijPrecomputeTimingRows(obj,rows,timing)
            if obj.isFiniteTimingValue(timing,'dijPrecomputingTimeSeconds')
                rows(end + 1,:) = {'Precompute dij time (s)', ...
                    planWorkflow.gui.ValueFormat.seconds( ...
                    timing.dijPrecomputingTimeSeconds),'', ...
                    ['Elapsed real time used to precompute dose influence ' ...
                     'matrices for this plan.']};
            end
            if obj.isFiniteTimingValue(timing,'relativeDijPrecomputingTime')
                rows(end + 1,:) = {'Precompute relative dij time', ...
                    planWorkflow.gui.ValueFormat.ratio( ...
                    timing.relativeDijPrecomputingTime),'', ...
                    ['Dose influence precompute time normalized to the ' ...
                     'reference plan dij precompute time.']};
            end
        end

        function rows = appendOptimizationTimingRows(obj,rows,timing)
            if obj.isFiniteTimingValue(timing,'timePerIterationSeconds')
                rows(end + 1,:) = {'Optimize TPI (s/iter)', ...
                    planWorkflow.gui.ValueFormat.seconds( ...
                    timing.timePerIterationSeconds),'', ...
                    ['Average elapsed real time per fluence optimization ' ...
                     'iteration.']};
            end
            if obj.isFiniteTimingValue(timing,'rTPI')
                rows(end + 1,:) = {'Optimize rTPI', ...
                    planWorkflow.gui.ValueFormat.ratio(timing.rTPI),'', ...
                    ['Relative time per iteration normalized to the ' ...
                     'reference plan in this workflow.']};
            end
        end

        function tf = isFiniteTimingValue(~,timing,fieldName)
            tf = isstruct(timing) && isfield(timing,fieldName) && ...
                isnumeric(timing.(fieldName)) && ...
                isscalar(timing.(fieldName)) && isfinite(timing.(fieldName));
        end

        function text = timingDetailText(obj,timing) %#ok<INUSD>
            text = '';
            if isstruct(timing) && isfield(timing,'detail') && ...
                    ~isempty(timing.detail)
                text = char(timing.detail);
            end
        end

        function detail = parseDetailJson(obj,text) %#ok<INUSD>
            try
                detail = jsondecode(char(text));
            catch
                detail = struct('raw',char(text));
            end
        end

        function lines = jsonDisplayLines(obj,text)
            rawText = char(string(text));
            if isempty(strtrim(rawText))
                lines = {'{}'};
                return;
            end

            try
                value = jsondecode(rawText);
                lines = obj.valueDisplayLines(value,0,'');
            catch
                lines = cellstr(rawText);
            end

            if isempty(lines)
                lines = {'{}'};
            end
        end

        function lines = valueDisplayLines(obj,value,indent,prefix)
            indentText = repmat(' ',1,indent);
            prefixText = '';
            if ~isempty(prefix)
                prefixText = [char(prefix) ': '];
            end

            if isstruct(value)
                lines = obj.structDisplayLines( ...
                    value,indent,indentText,prefixText);
            elseif iscell(value)
                lines = obj.cellDisplayLines(value,indent, ...
                    indentText,prefixText);
            elseif obj.isScalarDisplayValue(value)
                lines = {[indentText prefixText obj.scalarDisplayText(value)]};
            else
                lines = {[indentText prefixText obj.valueText(value)]};
            end
        end

        function lines = structDisplayLines(obj,value,indent,indentText, ...
                prefixText)
            lines = {};
            if numel(value) ~= 1
                if ~isempty(prefixText)
                    lines(end + 1,1) = ...
                        {[indentText prefixText(1:end - 2) ':']};
                end
                for i = 1:numel(value)
                    lines(end + 1,1) = {sprintf('%s- item %d:', ...
                        repmat(' ',1,indent + 2),i)}; %#ok<AGROW>
                    lines = [lines; ...
                        obj.valueDisplayLines(value(i),indent + 4,'')]; %#ok<AGROW>
                end
                return;
            end

            if ~isempty(prefixText)
                lines(end + 1,1) = ...
                    {[indentText prefixText(1:end - 2) ':']};
                indent = indent + 2;
                indentText = repmat(' ',1,indent);
            end

            fields = fieldnames(value);
            if isempty(fields)
                lines(end + 1,1) = {[indentText '{}']};
                return;
            end

            for i = 1:numel(fields)
                fieldName = fields{i};
                fieldValue = value.(fieldName);
                if obj.isScalarDisplayValue(fieldValue)
                    lines(end + 1,1) = {sprintf('%s%s: %s', ...
                        indentText,fieldName, ...
                        obj.scalarDisplayText(fieldValue))}; %#ok<AGROW>
                else
                    lines = [lines; ...
                        obj.valueDisplayLines(fieldValue,indent,fieldName)]; %#ok<AGROW>
                end
            end
        end

        function lines = cellDisplayLines(obj,value,indent,indentText, ...
                prefixText)
            lines = {};
            if ~isempty(prefixText)
                lines(end + 1,1) = ...
                    {[indentText prefixText(1:end - 2) ':']};
                indent = indent + 2;
                indentText = repmat(' ',1,indent);
            end

            if isempty(value)
                lines(end + 1,1) = {[indentText '[]']};
                return;
            end

            for i = 1:numel(value)
                item = value{i};
                if obj.isScalarDisplayValue(item)
                    lines(end + 1,1) = {sprintf('%s- %s', ...
                        indentText,obj.scalarDisplayText(item))}; %#ok<AGROW>
                else
                    lines(end + 1,1) = {[indentText '-']}; %#ok<AGROW>
                    lines = [lines; ...
                        obj.valueDisplayLines(item,indent + 2,'')]; %#ok<AGROW>
                end
            end
        end

        function tf = isScalarDisplayValue(obj,value) %#ok<INUSD>
            tf = isempty(value) || ischar(value) || isstring(value) || ...
                islogical(value) || ...
                (isnumeric(value) && (isempty(value) || isvector(value)));
        end

        function text = scalarDisplayText(obj,value)
            if ischar(value)
                text = value;
            elseif isstring(value)
                text = char(strjoin(value(:)',', '));
            elseif islogical(value) && isscalar(value)
                text = char(string(value));
            elseif isnumeric(value) || islogical(value)
                text = mat2str(value);
            elseif isempty(value)
                text = '[]';
            else
                text = obj.valueText(value);
            end
        end

        function rows = gammaSummaryRows(obj,planResults,runConfig)
            rows = {};
            if isstruct(runConfig) && isfield(runConfig,'analysis') && ...
                    isstruct(runConfig.analysis)
                analysis = runConfig.analysis;
                if isfield(analysis,'gammaCriteria')
                    rows(end + 1,:) = {'Gamma criteria', ...
                        obj.valueText(analysis.gammaCriteria),'', ...
                        'Gamma distance-to-agreement and dose-difference criteria used for sampling analysis.'};
                end
                if isfield(analysis,'gammaWindow')
                    rows(end + 1,:) = {'Gamma window', ...
                        obj.valueText(analysis.gammaWindow),'', ...
                        'Display window used for gamma analysis figures.'};
                end
            end
            if isfield(planResults,'doseStat') && ...
                    isfield(planResults.doseStat,'gammaAnalysis') && ...
                    isfield(planResults.doseStat.gammaAnalysis,'gammaPassRate')
                rows(end + 1,:) = {'Gamma pass rate', ...
                        obj.valueText( ...
                    planResults.doseStat.gammaAnalysis.gammaPassRate),'', ...
                    'Percentage of evaluated points that pass the gamma criterion.'};
            end
        end

        function rows = robustnessSummaryRows(obj,planResults)
            rows = {};
            if ~isfield(planResults,'doseStat') || ...
                    ~isfield(planResults.doseStat,'robustnessAnalysis')
                return;
            end

            robustness = planResults.doseStat.robustnessAnalysis;
            if ~isstruct(robustness)
                return;
            end

            indexFields = {'index1','index2'};
            indexLabels = {'RI1','RI2'};
            for i = 1:numel(indexFields)
                if ~isfield(robustness,indexFields{i})
                    continue;
                end
                entry = robustness.(indexFields{i});
                if isstruct(entry) && isfield(entry,'robustnessIndex')
                    rows(end + 1,:) = {indexLabels{i}, ...
                        obj.significantText(entry.robustnessIndex,3), ...
                        'fieldHelp', ...
                        obj.robustnessIndexHelpText(indexLabels{i})}; %#ok<AGROW>
                end
            end
        end

        function rows = priceOfRobustnessSummaryRows(obj,planResults, ...
                runConfig,referencePlanResults)
            rows = {};
            clinicalRows = obj.clinicalRows( ...
                planResults,runConfig,referencePlanResults);
            if isempty(clinicalRows)
                return;
            end

            for i = 1:size(clinicalRows,1)
                label = sprintf('%s - %s', ...
                    char(clinicalRows{i,1}),char(clinicalRows{i,2}));
                value = planWorkflow.analysis.ResultLogger.formatNumber( ...
                    clinicalRows{i,9});
                if ~isempty(clinicalRows{i,10}) && ...
                        ~strcmp(value,'-')
                value = sprintf('%s %s',value,char(clinicalRows{i,10}));
                end
                rows(end + 1,:) = {label,value,'',''}; %#ok<AGROW>
            end
        end

        function text = robustnessTargetsText(obj,runConfig) %#ok<INUSD>
            text = 'All structures';
            if ~isstruct(runConfig) || ~isfield(runConfig,'analysis') || ...
                    ~isstruct(runConfig.analysis)
                return;
            end

            analysis = runConfig.analysis;
            mode = 'all';
            if isfield(analysis,'robustnessTargetMode') && ...
                    ~isempty(analysis.robustnessTargetMode)
                mode = char(analysis.robustnessTargetMode);
            end
            if strcmp(mode,'all')
                return;
            end

            targets = {};
            if isfield(analysis,'robustnessTargets') && ...
                    ~isempty(analysis.robustnessTargets)
                targets = analysis.robustnessTargets;
            end
            if ischar(targets) || isstring(targets)
                targets = cellstr(targets);
            end
            if isempty(targets)
                targetText = 'None';
            else
                targetText = strjoin(cellfun(@char,targets, ...
                    'UniformOutput',false),', ');
            end
            text = sprintf('%s: %s',mode,targetText);
        end

        function qi = qiSource(~,planResults)
            qi = [];
            if ~isstruct(planResults)
                return;
            end
            if isfield(planResults,'expectedQi') && ...
                    ~isempty(planResults.expectedQi)
                qi = planResults.expectedQi;
            elseif isfield(planResults,'qi') && ~isempty(planResults.qi)
                qi = planResults.qi;
            end
        end

        function columns = qiColumnNames(~)
            columns = {'Structure','COV1','COV95','COV98','COV99', ...
                'Mean','SpatialSD','UncertHW','Min','Max','D95','D98', ...
                'D2','D50'};
        end

        function rows = qiRows(obj,qi,planResults)
            fields = {'COV1','COV_95','COV_98','COV_99','mean', ...
                'spatialStdDose','uncertaintyHalfWidth','min','max', ...
                'D_95','D_98','D_2','D_50'};
            rows = cell(numel(qi),numel(fields) + 1);
            context = ...
                planWorkflow.analysis.PlanEvaluationContext.fromPlanResults( ...
                planResults);
            for i = 1:numel(qi)
                rows{i,1} = obj.structureName(qi(i),i);
                for j = 1:numel(fields)
                    rows{i,j + 1} = ...
                        planWorkflow.analysis.ResultLogger.formatMetricValue( ...
                        qi(i),fields{j},context,planResults,i);
                end
            end
        end

        function columns = clinicalColumnNames(~)
            columns = planWorkflow.gui.ClinicalEndpointTableModel.columnNames();
        end

        function rows = clinicalRows(~,planResults,runConfig, ...
                referencePlanResults)
            if nargin < 4
                referencePlanResults = [];
            end
            rows = planWorkflow.gui.ClinicalEndpointTableModel.rows( ...
                planResults,runConfig,referencePlanResults);
        end

        function reference = referenceResults(obj,results) %#ok<INUSD>
            reference = [];
            if isstruct(results) && isfield(results,'reference')
                reference = results.reference;
            end
        end

        function robust = robustResult(obj,results,resultIx) %#ok<INUSD>
            robust = [];
            if isstruct(results) && isfield(results,'robust') && ...
                    numel(results.robust) >= resultIx
                robust = results.robust{resultIx};
            end
        end

        function reference = referenceSamplingResults(obj,sampling) %#ok<INUSD>
            reference = [];
            if isstruct(sampling) && isfield(sampling,'reference')
                reference = sampling.reference;
            end
        end

        function identity = referencePlanIdentity(obj) %#ok<MANU>
            identity = struct();
            identity.role = 'reference';
            identity.robustPlanId = '';
            identity.variantId = '';
        end

        function identity = analysisRobustPlanIdentity(obj,planResults, ...
                runConfig,resultIx)
            identity = obj.samplingRobustPlanIdentity( ...
                planResults,runConfig,resultIx);
            if isstruct(planResults)
                if isfield(planResults,'robustPlanId')
                    identity.robustPlanId = char(planResults.robustPlanId);
                end
                if isfield(planResults,'variantId')
                    identity.variantId = char(planResults.variantId);
                end
            end
        end

        function identity = samplingRobustPlanIdentity(obj,planResults, ...
                runConfig,resultIx) %#ok<INUSD>
            identity = struct();
            identity.role = 'robust';
            identity.robustPlanId = '';
            identity.variantId = '';

            robustPlans = ...
                planWorkflow.config.RobustPlanConfig.plansFromRunConfig( ...
                runConfig);
            if isempty(robustPlans)
                return;
            end

            resultCount = 0;
            robustPlans = robustPlans(:)';
            for planIx = 1:numel(robustPlans)
                planConfig = robustPlans(planIx);
                numVariants = 1;
                if isfield(planConfig,'variants') && ...
                        ~isempty(planConfig.variants)
                    numVariants = numel(planConfig.variants);
                end
                for variantIx = 1:numVariants
                    resultCount = resultCount + 1;
                    if resultCount == resultIx
                        if isfield(planConfig,'id')
                            identity.robustPlanId = char(planConfig.id);
                        end
                        if isfield(planConfig,'variants') && ...
                                ~isempty(planConfig.variants) && ...
                                isfield(planConfig.variants(variantIx),'id')
                            identity.variantId = ...
                                char(planConfig.variants(variantIx).id);
                        end
                        return;
                    end
                end
            end
        end

        function value = optionValue(obj,options,fieldName,defaultValue) %#ok<INUSD>
            value = defaultValue;
            if isstruct(options) && isfield(options,fieldName)
                value = options.(fieldName);
            end
        end

        function value = numericTimingValue(obj,timing,fieldName,defaultValue) %#ok<INUSD>
            value = defaultValue;
            if isstruct(timing) && isfield(timing,fieldName) && ...
                    isnumeric(timing.(fieldName)) && ...
                    isscalar(timing.(fieldName)) && ...
                    isfinite(timing.(fieldName))
                value = timing.(fieldName);
            end
        end

        function name = structureName(~,entry,index)
            if isfield(entry,'name')
                name = char(entry.name);
            elseif isfield(entry,'VOIname')
                name = char(entry.VOIname);
            else
                name = sprintf('structure_%d',index);
            end
        end

        function text = valueText(obj,value)
            if ischar(value)
                text = value;
            elseif isstring(value)
                text = char(value);
            elseif isnumeric(value) || islogical(value)
                text = mat2str(value);
            elseif iscell(value)
                text = strjoin(cellfun(@(item) obj.valueText(item), ...
                    value,'UniformOutput',false),', ');
            elseif isstruct(value)
                text = jsonencode(value);
            elseif isempty(value)
                text = '[]';
            else
                text = char(string(value));
            end
        end

        function text = significantText(~,value,numSig)
            if nargin < 3
                numSig = 3;
            end
            if isnumeric(value) && isscalar(value) && isfinite(value)
                format = sprintf('%%.%dg',numSig);
                text = sprintf(format,double(value));
            else
                text = '-';
            end
        end

        function text = robustnessIndexHelpText(~,indexName)
            if nargin < 2
                indexName = 'all';
            end
            switch char(indexName)
                case 'RI1'
                    text = ['Selected-target fraction passing the ' ...
                        'combined normalized mean-dose deviation and ' ...
                        'dose-standard-deviation Delta Index. Values are ' ...
                        'normalized from 0 to 1; higher is better.'];
                case 'RI2'
                    text = ['Selected-target fraction passing both ' ...
                        'binary mean-dose and standard-deviation criteria. ' ...
                        'Values are normalized from 0 to 1; higher is ' ...
                        'better.'];
                otherwise
                    text = ['RI1 and RI2 are robustness index values over ' ...
                        'the selected targets. Values are normalized from ' ...
                        '0 to 1; higher is better.'];
            end
        end
    end

    methods (Static, Access = private)
        function value = timingValue(timing,fieldName,defaultValue)
            if isfield(timing,fieldName)
                value = timing.(fieldName);
            else
                value = defaultValue;
            end
        end

    end
end
