classdef (Abstract) WorkflowBase < handle
    % WorkflowBase Base class for staged planWorkflow workflows.
    %
    % Subclasses implement the clinical/domain-specific steps while this
    % class owns the common lifecycle, state persistence, artifact paths,
    % resume support, and console output.

    properties
        runConfig
        stageConfig
        data
        state
        guiProgressReporter = []
    end

    properties (SetAccess = protected)
        matRadCfg
        runId
        rootPath
        folderPath
        cachePath
        stateFile
        dataFile
        resultsFile
        performanceFile
    end

    methods
        function obj = WorkflowBase(config)
            if nargin < 1
                config = struct();
            end
            obj.matRadCfg = MatRad_Config.instance();
            obj.data = struct();
            obj.state = obj.defaultState();
            obj.stageConfig = obj.defaultStageConfig();
            obj.runConfig = obj.parseRunConfig(config);
            obj.configurePaths();
        end

        function configure(obj,varargin)
            if isempty(varargin)
                return;
            end

            previousRunConfig = obj.runConfig;
            patch = obj.parseConfigArguments(varargin{:});
            patch = obj.expandRunConfig(patch);
            obj.runConfig = obj.mergeStruct(obj.runConfig,patch);
            obj.runConfig = obj.normalizeRunConfig(obj.runConfig);
            obj.configurePaths();

            if ~isequaln(previousRunConfig,obj.runConfig)
                obj.invalidateStages(obj.stageCompletedNames('prepare'));
                obj.markStateChange('config:global');
            end
        end

        function prepare(obj,varargin)
            stageName = 'prepare';
            completedName = obj.completedNameForStage(stageName);
            obj.configureStage(stageName,varargin{:});

            if obj.isStageComplete(completedName)
                obj.log('Workflow is already prepared.');
                return;
            end

            obj.beforePrepareStage();
            obj.ensureFolders();
            obj.runMeasuredStage(stageName,completedName,@() obj.doPrepare());
            obj.markStageComplete(completedName);
            obj.saveState();
        end

        function gui(obj,varargin)
            if ~isempty(varargin)
                if obj.isStageComplete(obj.completedNameForStage('prepare'))
                    error('planWorkflow:WorkflowBase:GuiReadOnlyConfig', ...
                        ['workflow.gui() can only edit configuration before ' ...
                         'prepare(). Open it without arguments to inspect or ' ...
                         'resume an existing workflow.']);
                end
                obj.configure(varargin{:});
            end

            if ~obj.hasInteractiveGuiSupport()
                obj.guiProgressReporter = [];
                obj.log('Interactive plan editor skipped because MATLAB UI is unavailable.');
                return;
            end

            obj.guiProgressReporter = obj.doGui();
            obj.configureGuiProgressReporter();
            if isempty(obj.state.completedStages)
                obj.markStateChange('gui');
            end
        end

        function precompute(obj,varargin)
            stageName = 'precompute';
            completedName = obj.completedNameForStage(stageName);
            obj.configureStage(stageName,varargin{:});

            if ~obj.isStageComplete(obj.completedNameForStage('prepare'))
                obj.prepare();
            end

            if obj.isStageComplete(completedName)
                obj.log('Workflow is already precomputed.');
                return;
            end

            obj.ensureFolders();
            obj.runMeasuredStage(stageName,completedName,@() obj.doPrecompute());
            obj.markStageComplete(completedName);
            obj.saveState();
        end

        function optimize(obj,varargin)
            stageName = 'optimize';
            completedName = obj.completedNameForStage(stageName);
            obj.configureStage(stageName,varargin{:});

            if ~obj.isStageComplete(obj.completedNameForStage('pullDose'))
                obj.pullDose();
            end

            if obj.isStageComplete(completedName)
                obj.log('Workflow is already optimized.');
                return;
            end

            obj.runMeasuredStage(stageName,completedName,@() obj.doOptimize());
            obj.markStageComplete(completedName);
            obj.saveState();
        end

        function pullDose(obj,varargin)
            stageName = 'pullDose';
            completedName = obj.completedNameForStage(stageName);
            obj.configureStage(stageName,varargin{:});

            if ~obj.isStageComplete(obj.completedNameForStage('precompute'))
                obj.precompute();
            end

            if obj.isStageComplete(completedName)
                obj.log('Workflow dose pulling is already complete.');
                return;
            end

            obj.runMeasuredStage(stageName,completedName, ...
                @() obj.doDosePulling());
            obj.invalidateStages(obj.stageCompletedNames('optimize'));
            obj.markStageComplete(completedName);
            obj.saveState();
        end

        function sample(obj,varargin)
            stageName = 'sample';
            completedName = obj.completedNameForStage(stageName);
            obj.configureStage(stageName,varargin{:});

            if ~obj.isStageComplete(obj.completedNameForStage('optimize'))
                obj.optimize();
            end

            if obj.isStageComplete(completedName)
                obj.log('Workflow is already sampled.');
                return;
            end

            obj.runMeasuredStage(stageName,completedName,@() obj.doSampling());
            obj.invalidateStages(obj.stageCompletedNames('analyze'));
            obj.markStageComplete(completedName);
            obj.saveState();
        end

        function analyze(obj,varargin)
            stageName = 'analyze';
            completedName = obj.completedNameForStage(stageName);
            obj.configureStage(stageName,varargin{:});

            if ~obj.isStageComplete(obj.completedNameForStage('optimize'))
                obj.optimize();
            end

            if obj.isStageComplete(completedName)
                obj.log('Workflow is already analyzed.');
                obj.reportGuiResults();
                return;
            end

            obj.runMeasuredStage(stageName,completedName,@() obj.doAnalyze());
            obj.markStageComplete(completedName);
            obj.saveState();
            obj.reportGuiResults();
        end

        function recalculateAnalysis(obj,varargin)
            obj.ensureWorkflowDataLoadedForReanalysis();
            stageName = 'analyze';
            completedName = obj.completedNameForStage(stageName);
            obj.configureStage(stageName,varargin{:});

            if ~obj.isStageComplete(obj.completedNameForStage('optimize'))
                error('planWorkflow:WorkflowBase:AnalysisRecalculationNeedsOptimization', ...
                    'Analysis can only be recalculated after optimization is complete.');
            end

            obj.runMeasuredStage(stageName,completedName,@() obj.doAnalyze());
            obj.markStageComplete(completedName);
            obj.saveState();
            obj.reportGuiResults();
        end

        function save(obj)
            obj.saveState();
        end

        function resume(obj,stateFile)
            if nargin < 2 || isempty(stateFile)
                stateFile = obj.stateFile;
            end

            obj.loadState(stateFile);
            obj.log(sprintf('Workflow resumed from %s.',stateFile));
        end

        function releaseMemory(obj)
            if isstruct(obj.data) && isempty(fieldnames(obj.data))
                return;
            end
            obj.data = struct();
            obj.log('Workflow in-memory data released. Persistent state remains on disk.');
        end

    end

    methods (Static)
        function obj = resumeFrom(stateFile)
            snapshot = load(stateFile,'runConfig','className');
            if ~isfield(snapshot,'className') || isempty(snapshot.className)
                error('planWorkflow:WorkflowBase:MissingClassName', ...
                    'The state file does not contain workflow class metadata.');
            end

            className = snapshot.className;
            obj = feval(className,snapshot.runConfig);
            obj.resume(stateFile);
        end
    end

    methods (Access = protected)
        function runConfig = parseRunConfig(obj,config)
            if isempty(config)
                config = struct();
            end
            if isstruct(config)
                runConfig = config;
            else
                error('planWorkflow:WorkflowBase:InvalidInput', ...
                    'Use a workflow config struct.');
            end

            runConfig = obj.expandRunConfig(runConfig);
            runConfig = obj.mergeDefaults(runConfig,obj.defaultRunConfig());
            runConfig = obj.normalizeRunConfig(runConfig);
        end

        function runConfig = applyNameValue(~,runConfig,args)
            if mod(numel(args),2) ~= 0
                error('planWorkflow:WorkflowBase:InvalidNameValue', ...
                    'Name/value arguments must come in pairs.');
            end

            for k = 1:2:numel(args)
                fieldName = char(args{k});
                runConfig.(fieldName) = args{k + 1};
            end
        end

        function config = parseConfigArguments(obj,varargin)
            if isscalar(varargin) && isstruct(varargin{1})
                config = varargin{1};
            else
                config = obj.applyNameValue(struct(),varargin);
            end
        end

        function configureStage(obj,stageName,varargin)
            stageName = planWorkflow.config.StageConfigSchema.engineStageName( ...
                stageName);
            if isempty(varargin)
                return;
            end

            obj.assertValidStageName(stageName);
            stagePatch = obj.parseConfigArguments(varargin{:});
            stagePatch = obj.normalizeStageConfig(stageName,stagePatch);
            obj.validateStageConfigFields(stageName,stagePatch);

            previousRunConfig = obj.runConfig;
            previousStageConfig = obj.stageConfig;
            obj.stageConfig.(stageName) = obj.mergeStruct( ...
                obj.stageConfig.(stageName),stagePatch);

            runPatch = obj.stageConfigToRunConfig(stageName,stagePatch);
            obj.runConfig = obj.mergeStruct(obj.runConfig,runPatch);
            obj.runConfig = obj.normalizeRunConfig(obj.runConfig);
            obj.configurePaths();

            if ~isequaln(previousRunConfig,obj.runConfig) || ...
                    ~isequaln(previousStageConfig,obj.stageConfig)
                obj.invalidateStages(obj.stageCompletedNames(stageName));
                obj.markStateChange(['config:' stageName]);
            end
        end

        function validateStageConfigFields(obj,stageName,stageConfig)
            allowedFields = obj.stageConfigFields(stageName);
            configFields = fieldnames(stageConfig);
            for i = 1:numel(configFields)
                if ~any(strcmp(configFields{i},allowedFields))
                    replacement = ...
                        planWorkflow.config.StageConfigSchema.unsupportedFieldReplacement( ...
                        stageName,configFields{i});
                    if ~isempty(replacement)
                        error('planWorkflow:WorkflowBase:UnsupportedStageConfigField', ...
                            ['Unsupported %s config field "%s". Use ' ...
                             '"%s" instead. Valid fields are: %s.'], ...
                            stageName,configFields{i},replacement, ...
                            strjoin(allowedFields,', '));
                    end
                    error('planWorkflow:WorkflowBase:UnsupportedStageConfigField', ...
                        'Unsupported %s config field "%s". Valid fields are: %s.', ...
                        stageName,configFields{i},strjoin(allowedFields,', '));
                end
            end
        end

        function assertValidStageName(obj,stageName)
            if ~any(strcmp(stageName,obj.stageOrder()))
                error('planWorkflow:WorkflowBase:UnknownStage', ...
                    'Unknown workflow stage "%s".',stageName);
            end
        end

        function stageConfig = defaultStageConfig(obj)
            stageConfig = struct();
            stages = obj.stageOrder();
            for i = 1:numel(stages)
                stageConfig.(stages{i}) = struct();
            end
        end

        function fields = stageConfigFields(~,~)
            fields = {};
        end

        function stageConfig = normalizeStageConfig(~,~,stageConfig)
        end

        function runConfig = expandRunConfig(~,runConfig)
        end

        function beforePrepareStage(~)
        end

        function reporter = doGui(~)
            reporter = [];
        end

        function configureGuiProgressReporter(obj,reporter)
            if nargin >= 2 && ~isempty(reporter)
                obj.guiProgressReporter = reporter;
            end
            reporter = obj.guiProgressReporter;
            if isempty(reporter)
                return;
            end

            try
                if isa(reporter,'handle') && ~isvalid(reporter)
                    return;
                end
            catch
            end

            try
                if ismethod(reporter,'setRecalculateAnalysisCallback')
                    reporter.setRecalculateAnalysisCallback( ...
                        @(varargin) obj.recalculateAnalysis(varargin{:}));
                end
            catch
            end
        end

        function ensureWorkflowDataLoadedForReanalysis(obj)
            if isstruct(obj.data) && ~isempty(fieldnames(obj.data))
                return;
            end

            if isempty(obj.stateFile) || ~isfile(obj.stateFile)
                error('planWorkflow:WorkflowBase:MissingAnalysisState', ...
                    ['Analysis cannot be recalculated because no in-memory ' ...
                     'workflow data or saved workflow state is available.']);
            end

            obj.loadState(obj.stateFile);
            obj.log(sprintf(['Workflow data reloaded from %s for analysis ' ...
                'recalculation.'],obj.stateFile));
        end

        function tf = hasInteractiveGuiSupport(~)
            tf = usejava('desktop');
        end

        function runConfig = stageConfigToRunConfig(~,~,stageConfig)
            runConfig = stageConfig;
        end

        function merged = mergeStruct(obj,base,patch)
            merged = base;
            patchFields = fieldnames(patch);
            for i = 1:numel(patchFields)
                fieldName = patchFields{i};
                if isfield(merged,fieldName) && isstruct(merged.(fieldName)) && ...
                        isstruct(patch.(fieldName)) && isscalar(merged.(fieldName)) && ...
                        isscalar(patch.(fieldName))
                    merged.(fieldName) = obj.mergeStruct( ...
                        merged.(fieldName),patch.(fieldName));
                else
                    merged.(fieldName) = patch.(fieldName);
                end
            end
        end

        function stages = stageOrder(obj) %#ok<MANU>
            stages = planWorkflow.config.StageConfigSchema.engineStageNames();
        end

        function stageNames = stageCompletedNames(~,stageName)
            stageNames = ...
                planWorkflow.config.StageConfigSchema.completedNamesFrom( ...
                stageName);
        end

        function completedStageName = completedNameForStage(obj,stageName) %#ok<INUSD>
            completedStageName = ...
                planWorkflow.config.StageConfigSchema.completedName( ...
                stageName);
        end

        function stageName = stageNameFromCompleted(obj,completedStageName) %#ok<INUSD>
            stageName = ...
                planWorkflow.config.StageConfigSchema.stageNameFromCompleted( ...
                completedStageName);
        end

        function stageName = nextIncompleteStage(obj)
            stageName = 'complete';
            stages = obj.stageOrder();
            for i = 1:numel(stages)
                completedStageName = obj.completedNameForStage(stages{i});
                if ~obj.isStageComplete(completedStageName)
                    stageName = stages{i};
                    return;
                end
            end
        end

        function timings = defaultStageTimings(obj)
            timings = struct();
            stages = obj.stageOrder();
            for i = 1:numel(stages)
                timings.(stages{i}) = obj.emptyStageTiming(stages{i});
            end
        end

        function timing = emptyStageTiming(obj,stageName)
            timing = struct();
            timing.stage = stageName;
            timing.completedStage = obj.completedNameForStage(stageName);
            timing.isCurrent = false;
            timing.attempts = 0;
            timing.totalWallTimeSeconds = 0;
            timing.totalCpuTimeSeconds = 0;
            timing.lastStatus = '';
            timing.lastStartTime = '';
            timing.lastEndTime = '';
            timing.lastWallTimeSeconds = NaN;
            timing.lastCpuTimeSeconds = NaN;
            timing.lastStartProcessMemoryBytes = NaN;
            timing.lastEndProcessMemoryBytes = NaN;
            timing.lastProcessMemoryDeltaBytes = NaN;
            timing.lastMaxObservedProcessMemoryBytes = NaN;
            timing.peakObservedProcessMemoryBytes = NaN;
            timing.lastStartChildProcessMemoryBytes = NaN;
            timing.lastEndChildProcessMemoryBytes = NaN;
            timing.lastChildProcessMemoryDeltaBytes = NaN;
            timing.lastHighWaterMainProcessMemoryBytes = NaN;
            timing.lastHighWaterChildProcessMemoryBytes = NaN;
            timing.lastHighWaterTotalProcessMemoryBytes = NaN;
            timing.lastChildProcessBuckets = ...
                planWorkflow.resources.ResourceSampler.disabledSummary().childProcessBuckets;
            timing.peakHighWaterMainProcessMemoryBytes = NaN;
            timing.peakHighWaterChildProcessMemoryBytes = NaN;
            timing.peakHighWaterTotalProcessMemoryBytes = NaN;
            timing.lastStartDataMemoryBytes = NaN;
            timing.lastEndDataMemoryBytes = NaN;
            timing.lastDataMemoryDeltaBytes = NaN;
            timing.peakDataMemoryBytes = NaN;
            timing.memorySource = '';
            timing.memoryUnavailableCause = '';
            timing.lastErrorMessage = '';
            timing.history = {};
        end

        function state = normalizeState(obj,state)
            defaults = obj.defaultState();
            defaultFields = fieldnames(defaults);
            for i = 1:numel(defaultFields)
                fieldName = defaultFields{i};
                if ~isfield(state,fieldName)
                    state.(fieldName) = defaults.(fieldName);
                end
            end

            stages = obj.stageOrder();
            if ~isstruct(state.stageTimings)
                state.stageTimings = obj.defaultStageTimings();
                return;
            end

            for i = 1:numel(stages)
                stageName = stages{i};
                defaultTiming = obj.emptyStageTiming(stageName);
                if ~isfield(state.stageTimings,stageName) || ...
                        ~isstruct(state.stageTimings.(stageName))
                    state.stageTimings.(stageName) = defaultTiming;
                else
                    state.stageTimings.(stageName) = obj.mergeDefaults( ...
                        state.stageTimings.(stageName),defaultTiming);
                end
            end
        end

        function runMeasuredStage(obj,stageName,completedStageName,stageFunction)
            startTime = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            wallTimer = tic;
            startCpuTime = cputime;
            resourceSampler = obj.startResourceSampler();
            startDataMemoryBytes = obj.matlabVariableBytes(obj.data);
            obj.reportGuiStageStarted(stageName);

            try
                obj.assertGuiExecutionNotStopped();
                stageFunction();
                obj.assertGuiExecutionNotStopped();
                wallTimeSeconds = toc(wallTimer);
                cpuTimeSeconds = cputime - startCpuTime;
                memoryRecord = obj.stageMemoryRecord(resourceSampler, ...
                    startDataMemoryBytes);
                obj.recordStageTiming(stageName,completedStageName,startTime, ...
                    wallTimeSeconds,cpuTimeSeconds,'completed','', ...
                    memoryRecord);
                obj.reportGuiStageCompleted(stageName,wallTimeSeconds);
            catch ME
                wallTimeSeconds = toc(wallTimer);
                cpuTimeSeconds = cputime - startCpuTime;
                memoryRecord = obj.stageMemoryRecord(resourceSampler, ...
                    startDataMemoryBytes);
                obj.recordStageTiming(stageName,completedStageName,startTime, ...
                    wallTimeSeconds,cpuTimeSeconds,'failed', ...
                    ME.message,memoryRecord);
                obj.reportGuiStageFailed(stageName,ME.message);
                obj.trySaveFailedStageState(stageName);
                rethrow(ME);
            end
        end

        function varargout = runMeasuredPlanTask(obj,stageName,role, ...
                label,taskName,robustPlanId,variantId,taskFunction)
            startTime = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            wallTimer = tic;
            startCpuTime = cputime;
            resourceSampler = obj.startResourceSampler();
            startDataMemoryBytes = obj.matlabVariableBytes(obj.data);
            taskOutputs = {};

            try
                obj.assertGuiExecutionNotStopped();
                if nargout > 0
                    [varargout{1:nargout}] = taskFunction();
                    taskOutputs = varargout;
                else
                    taskFunction();
                end
                obj.assertGuiExecutionNotStopped();
                wallTimeSeconds = toc(wallTimer);
                cpuTimeSeconds = cputime - startCpuTime;
                memoryRecord = obj.stageMemoryRecord(resourceSampler, ...
                    startDataMemoryBytes);
                detail = obj.planTaskResourceDetail(stageName,role,label, ...
                    taskName,robustPlanId,variantId,taskOutputs);
                obj.recordPlanTiming(stageName,role,label,taskName, ...
                    robustPlanId,variantId,startTime,wallTimeSeconds, ...
                    cpuTimeSeconds,'completed','',memoryRecord,detail);
            catch ME
                wallTimeSeconds = toc(wallTimer);
                cpuTimeSeconds = cputime - startCpuTime;
                memoryRecord = obj.stageMemoryRecord(resourceSampler, ...
                    startDataMemoryBytes);
                obj.recordPlanTiming(stageName,role,label,taskName, ...
                    robustPlanId,variantId,startTime,wallTimeSeconds, ...
                    cpuTimeSeconds,'failed',ME.message,memoryRecord,'');
                rethrow(ME);
            end
        end

        function recordStageTiming(obj,stageName,completedStageName,startTime, ...
                wallTimeSeconds,cpuTimeSeconds,status,errorMessage,memoryRecord)
            obj.state = obj.normalizeState(obj.state);
            endTime = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));

            record = struct();
            record.stage = stageName;
            record.completedStage = completedStageName;
            record.status = status;
            record.startTime = startTime;
            record.endTime = endTime;
            record.wallTimeSeconds = wallTimeSeconds;
            record.cpuTimeSeconds = cpuTimeSeconds;
            record.errorMessage = errorMessage;
            record.startProcessMemoryBytes = memoryRecord.startProcessMemoryBytes;
            record.endProcessMemoryBytes = memoryRecord.endProcessMemoryBytes;
            record.processMemoryDeltaBytes = ...
                memoryRecord.processMemoryDeltaBytes;
            record.maxObservedProcessMemoryBytes = ...
                memoryRecord.maxObservedProcessMemoryBytes;
            record.startChildProcessMemoryBytes = ...
                memoryRecord.startChildProcessMemoryBytes;
            record.endChildProcessMemoryBytes = ...
                memoryRecord.endChildProcessMemoryBytes;
            record.childProcessMemoryDeltaBytes = ...
                memoryRecord.childProcessMemoryDeltaBytes;
            record.highWaterMainProcessMemoryBytes = ...
                memoryRecord.highWaterMainProcessMemoryBytes;
            record.highWaterChildProcessMemoryBytes = ...
                memoryRecord.highWaterChildProcessMemoryBytes;
            record.highWaterTotalProcessMemoryBytes = ...
                memoryRecord.highWaterTotalProcessMemoryBytes;
            record.childProcessBuckets = memoryRecord.childProcessBuckets;
            record.startDataMemoryBytes = memoryRecord.startDataMemoryBytes;
            record.endDataMemoryBytes = memoryRecord.endDataMemoryBytes;
            record.dataMemoryDeltaBytes = memoryRecord.dataMemoryDeltaBytes;
            record.memorySource = memoryRecord.memorySource;
            record.memoryUnavailableCause = ...
                memoryRecord.memoryUnavailableCause;

            timing = obj.state.stageTimings.(stageName);
            timing.stage = stageName;
            timing.completedStage = completedStageName;
            timing.isCurrent = strcmp(status,'completed');
            timing.attempts = timing.attempts + 1;
            timing.totalWallTimeSeconds = timing.totalWallTimeSeconds + wallTimeSeconds;
            timing.totalCpuTimeSeconds = timing.totalCpuTimeSeconds + cpuTimeSeconds;
            timing.lastStatus = status;
            timing.lastStartTime = startTime;
            timing.lastEndTime = endTime;
            timing.lastWallTimeSeconds = wallTimeSeconds;
            timing.lastCpuTimeSeconds = cpuTimeSeconds;
            timing.lastStartProcessMemoryBytes = ...
                memoryRecord.startProcessMemoryBytes;
            timing.lastEndProcessMemoryBytes = ...
                memoryRecord.endProcessMemoryBytes;
            timing.lastProcessMemoryDeltaBytes = ...
                memoryRecord.processMemoryDeltaBytes;
            timing.lastMaxObservedProcessMemoryBytes = ...
                memoryRecord.maxObservedProcessMemoryBytes;
            timing.peakObservedProcessMemoryBytes = obj.maxFinite([ ...
                timing.peakObservedProcessMemoryBytes ...
                memoryRecord.maxObservedProcessMemoryBytes]);
            timing.lastStartChildProcessMemoryBytes = ...
                memoryRecord.startChildProcessMemoryBytes;
            timing.lastEndChildProcessMemoryBytes = ...
                memoryRecord.endChildProcessMemoryBytes;
            timing.lastChildProcessMemoryDeltaBytes = ...
                memoryRecord.childProcessMemoryDeltaBytes;
            timing.lastHighWaterMainProcessMemoryBytes = ...
                memoryRecord.highWaterMainProcessMemoryBytes;
            timing.lastHighWaterChildProcessMemoryBytes = ...
                memoryRecord.highWaterChildProcessMemoryBytes;
            timing.lastHighWaterTotalProcessMemoryBytes = ...
                memoryRecord.highWaterTotalProcessMemoryBytes;
            timing.lastChildProcessBuckets = memoryRecord.childProcessBuckets;
            timing.peakHighWaterMainProcessMemoryBytes = obj.maxFinite([ ...
                timing.peakHighWaterMainProcessMemoryBytes ...
                memoryRecord.highWaterMainProcessMemoryBytes]);
            timing.peakHighWaterChildProcessMemoryBytes = obj.maxFinite([ ...
                timing.peakHighWaterChildProcessMemoryBytes ...
                memoryRecord.highWaterChildProcessMemoryBytes]);
            timing.peakHighWaterTotalProcessMemoryBytes = obj.maxFinite([ ...
                timing.peakHighWaterTotalProcessMemoryBytes ...
                memoryRecord.highWaterTotalProcessMemoryBytes]);
            timing.lastStartDataMemoryBytes = memoryRecord.startDataMemoryBytes;
            timing.lastEndDataMemoryBytes = memoryRecord.endDataMemoryBytes;
            timing.lastDataMemoryDeltaBytes = memoryRecord.dataMemoryDeltaBytes;
            timing.peakDataMemoryBytes = obj.maxFinite([ ...
                timing.peakDataMemoryBytes memoryRecord.endDataMemoryBytes]);
            timing.memorySource = memoryRecord.memorySource;
            timing.memoryUnavailableCause = memoryRecord.memoryUnavailableCause;
            timing.lastErrorMessage = errorMessage;
            timing.history{end + 1} = record;

            obj.state.stageTimings.(stageName) = timing;
        end

        function memoryRecord = stageMemoryRecord(obj,resourceSampler, ...
                startDataMemoryBytes)
            if isempty(resourceSampler)
                resourceSummary = ...
                    planWorkflow.resources.ResourceSampler.disabledSummary();
            else
                resourceSummary = resourceSampler.finish();
            end
            endDataMemoryBytes = obj.matlabVariableBytes(obj.data);
            memoryRecord = struct();
            memoryRecord.startProcessMemoryBytes = ...
                resourceSummary.startMainProcessMemoryBytes;
            memoryRecord.endProcessMemoryBytes = ...
                resourceSummary.endMainProcessMemoryBytes;
            memoryRecord.processMemoryDeltaBytes = ...
                obj.finiteDelta(memoryRecord.endProcessMemoryBytes, ...
                memoryRecord.startProcessMemoryBytes);
            memoryRecord.maxObservedProcessMemoryBytes = obj.maxFinite([ ...
                memoryRecord.startProcessMemoryBytes ...
                memoryRecord.endProcessMemoryBytes ...
                resourceSummary.highWaterMainProcessMemoryBytes]);
            memoryRecord.startChildProcessMemoryBytes = ...
                resourceSummary.startChildProcessMemoryBytes;
            memoryRecord.endChildProcessMemoryBytes = ...
                resourceSummary.endChildProcessMemoryBytes;
            memoryRecord.childProcessMemoryDeltaBytes = ...
                obj.finiteDelta(memoryRecord.endChildProcessMemoryBytes, ...
                memoryRecord.startChildProcessMemoryBytes);
            memoryRecord.highWaterMainProcessMemoryBytes = ...
                resourceSummary.highWaterMainProcessMemoryBytes;
            memoryRecord.highWaterChildProcessMemoryBytes = ...
                resourceSummary.highWaterChildProcessMemoryBytes;
            memoryRecord.highWaterTotalProcessMemoryBytes = ...
                resourceSummary.highWaterTotalProcessMemoryBytes;
            memoryRecord.childProcessBuckets = ...
                resourceSummary.childProcessBuckets;
            memoryRecord.startDataMemoryBytes = startDataMemoryBytes;
            memoryRecord.endDataMemoryBytes = endDataMemoryBytes;
            memoryRecord.dataMemoryDeltaBytes = obj.finiteDelta( ...
                endDataMemoryBytes,startDataMemoryBytes);
            memoryRecord.memorySource = resourceSummary.source;
            memoryRecord.memoryUnavailableCause = ...
                resourceSummary.unavailableCause;
        end

        function sampler = startResourceSampler(obj)
            resources = planWorkflow.config.Resources.fromRunConfig( ...
                obj.runConfig);
            if ~resources.memory.enabled
                sampler = [];
                return;
            end
            sampler = planWorkflow.resources.ResourceSampler.start( ...
                resources.memory);
        end

        function sample = processMemorySnapshot(~)
            sample = struct();
            sample.processMemoryBytes = NaN;
            sample.source = 'unavailable';

            try
                pid = feature('getpid');
                [status,output] = system(sprintf('ps -o rss= -p %d',pid));
                rssKbText = regexp(output,'\d+','match','once');
                if status == 0 && ~isempty(rssKbText)
                    sample.processMemoryBytes = str2double(rssKbText) * 1024;
                    sample.source = 'process_rss_ps';
                end
            catch
            end
        end

        function bytes = matlabVariableBytes(~,value) %#ok<INUSD>
            variableInfo = whos('value');
            bytes = variableInfo.bytes;
        end

        function value = finiteDelta(~,endValue,startValue)
            if isfinite(endValue) && isfinite(startValue)
                value = endValue - startValue;
            else
                value = NaN;
            end
        end

        function value = maxFinite(~,values)
            finiteValues = values(isfinite(values));
            if isempty(finiteValues)
                value = NaN;
            else
                value = max(finiteValues);
            end
        end

        function markStageTimingsStale(obj,completedStageNames)
            obj.state = obj.normalizeState(obj.state);
            for i = 1:numel(completedStageNames)
                stageName = obj.stageNameFromCompleted(completedStageNames{i});
                if ~isempty(stageName) && isfield(obj.state.stageTimings,stageName)
                    obj.state.stageTimings.(stageName).isCurrent = false;
                end
            end
        end

        function trySaveFailedStageState(obj,stageName)
            try
                obj.saveState();
            catch ME
                obj.log(sprintf('Could not save failed %s stage timing: %s', ...
                    stageName,ME.message));
            end
        end

        function stageSummary = stageTimingSummary(obj)
            obj.state = obj.normalizeState(obj.state);
            stageSummary = struct();
            stageSummary.wallTimeUnit = 'seconds';
            stageSummary.cpuTimeUnit = 'seconds';
            stageSummary.memoryUnit = 'bytes';
            stageSummary.processMemoryMetric = ...
                ['MATLAB process-tree resident set size sampled via ps ' ...
                '(main, child, and total high-water fields)'];
            stageSummary.dataMemoryMetric = ...
                'MATLAB bytes reported by whos for obj.data';
            stageSummary.stageTimings = obj.state.stageTimings;
        end

        function performance = performanceSummary(obj)
            performance = obj.stageTimingSummary();
            planTimings = planWorkflow.performance.PrecomputeTiming.enrich( ...
                obj.planTimingSummary());
            planTimings = planWorkflow.performance.PrecomputeSize.enrich( ...
                planTimings);
            performance.planTimings = ...
                planWorkflow.performance.OptimizationTiming.enrich( ...
                planTimings);
        end

        function planTimings = planTimingSummary(obj)
            planTimings = obj.emptyPlanTiming();
            planTimings(:) = [];
            if ~isstruct(obj.data) || ~isfield(obj.data,'performance') || ...
                    ~isstruct(obj.data.performance) || ...
                    ~isfield(obj.data.performance,'planTimings') || ...
                    ~isstruct(obj.data.performance.planTimings)
                return;
            end

            planTimings = obj.normalizePlanTimingArray( ...
                obj.data.performance.planTimings);
        end

        function detail = planTaskResourceDetail(obj,stageName,role,label, ...
                taskName,robustPlanId,variantId,taskOutputs) %#ok<INUSD>
            if nargin < 8
                taskOutputs = {};
            end
            detail = planWorkflow.performance.ResourceDetails.planTask( ...
                stageName,taskName,taskOutputs);
        end

        function label = planTimingLabel(obj,label,role,robustPlanId, ...
                variantId) %#ok<INUSD>
            label = char(label);
        end

        function attachResultsPerformance(obj)
            if isstruct(obj.data) && isfield(obj.data,'results') && ...
                    isstruct(obj.data.results)
                obj.data.results.performance = obj.performanceSummary();
            end
        end

        function recordPlanTiming(obj,stageName,role,label,taskName, ...
                robustPlanId,variantId,startTime,wallTimeSeconds, ...
                cpuTimeSeconds,status,errorMessage,memoryRecord,detail)
            if nargin < 14
                detail = '';
            end
            if ~isstruct(obj.data)
                obj.data = struct();
            end
            if ~isfield(obj.data,'performance') || ...
                    ~isstruct(obj.data.performance)
                obj.data.performance = struct();
            end
            if ~isfield(obj.data.performance,'planTimings') || ...
                    ~isstruct(obj.data.performance.planTimings)
                obj.data.performance.planTimings = obj.emptyPlanTiming();
                obj.data.performance.planTimings(:) = [];
            else
                obj.data.performance.planTimings = ...
                    obj.normalizePlanTimingArray( ...
                    obj.data.performance.planTimings);
            end

            record = obj.emptyPlanTiming();
            record.stage = char(stageName);
            record.role = char(role);
            record.label = char(obj.planTimingLabel(label,role, ...
                robustPlanId,variantId));
            record.task = char(taskName);
            record.robustPlanId = char(robustPlanId);
            record.variantId = char(variantId);
            record.status = char(status);
            record.startTime = char(startTime);
            record.endTime = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            record.wallTimeSeconds = wallTimeSeconds;
            record.cpuTimeSeconds = cpuTimeSeconds;
            record.detail = char(detail);
            record.errorMessage = char(errorMessage);
            record.startProcessMemoryBytes = memoryRecord.startProcessMemoryBytes;
            record.endProcessMemoryBytes = memoryRecord.endProcessMemoryBytes;
            record.processMemoryDeltaBytes = ...
                memoryRecord.processMemoryDeltaBytes;
            record.maxObservedProcessMemoryBytes = ...
                memoryRecord.maxObservedProcessMemoryBytes;
            record.startChildProcessMemoryBytes = ...
                memoryRecord.startChildProcessMemoryBytes;
            record.endChildProcessMemoryBytes = ...
                memoryRecord.endChildProcessMemoryBytes;
            record.childProcessMemoryDeltaBytes = ...
                memoryRecord.childProcessMemoryDeltaBytes;
            record.highWaterMainProcessMemoryBytes = ...
                memoryRecord.highWaterMainProcessMemoryBytes;
            record.highWaterChildProcessMemoryBytes = ...
                memoryRecord.highWaterChildProcessMemoryBytes;
            record.highWaterTotalProcessMemoryBytes = ...
                memoryRecord.highWaterTotalProcessMemoryBytes;
            record.childProcessBuckets = memoryRecord.childProcessBuckets;
            record.startDataMemoryBytes = memoryRecord.startDataMemoryBytes;
            record.endDataMemoryBytes = memoryRecord.endDataMemoryBytes;
            record.dataMemoryDeltaBytes = memoryRecord.dataMemoryDeltaBytes;
            record.memorySource = memoryRecord.memorySource;
            record.memoryUnavailableCause = memoryRecord.memoryUnavailableCause;

            obj.data.performance.planTimings(end + 1) = record;
        end

        function timing = emptyPlanTiming(obj) %#ok<MANU>
            timing = struct();
            timing.stage = '';
            timing.role = '';
            timing.label = '';
            timing.task = '';
            timing.robustPlanId = '';
            timing.variantId = '';
            timing.status = '';
            timing.startTime = '';
            timing.endTime = '';
            timing.wallTimeSeconds = NaN;
            timing.cpuTimeSeconds = NaN;
            timing.iterations = NaN;
            timing.timePerIterationSeconds = NaN;
            timing.rTPI = NaN;
            timing.rTPIReferenceLabel = '';
            timing.rTPIReferenceTimePerIterationSeconds = NaN;
            timing.dijPrecomputingTimeSeconds = NaN;
            timing.relativeDijPrecomputingTime = NaN;
            timing.dijPrecomputingReferenceLabel = '';
            timing.dijPrecomputingReferenceTimeSeconds = NaN;
            timing.dijPrecomputingSizeBytes = NaN;
            timing.relativeDijPrecomputingSize = NaN;
            timing.dijPrecomputingSizeReferenceLabel = '';
            timing.dijPrecomputingSizeReferenceBytes = NaN;
            timing.detail = '';
            timing.startProcessMemoryBytes = NaN;
            timing.endProcessMemoryBytes = NaN;
            timing.processMemoryDeltaBytes = NaN;
            timing.maxObservedProcessMemoryBytes = NaN;
            timing.startChildProcessMemoryBytes = NaN;
            timing.endChildProcessMemoryBytes = NaN;
            timing.childProcessMemoryDeltaBytes = NaN;
            timing.highWaterMainProcessMemoryBytes = NaN;
            timing.highWaterChildProcessMemoryBytes = NaN;
            timing.highWaterTotalProcessMemoryBytes = NaN;
            timing.childProcessBuckets = ...
                planWorkflow.resources.ResourceSampler.disabledSummary().childProcessBuckets;
            timing.startDataMemoryBytes = NaN;
            timing.endDataMemoryBytes = NaN;
            timing.dataMemoryDeltaBytes = NaN;
            timing.memorySource = '';
            timing.memoryUnavailableCause = '';
            timing.errorMessage = '';
        end

        function timings = normalizePlanTimingArray(obj,timings)
            defaultTiming = obj.emptyPlanTiming();
            if ~isstruct(timings)
                timings = defaultTiming;
                timings(:) = [];
                return;
            end
            normalizedTimings = repmat(defaultTiming,size(timings));
            for timingIx = 1:numel(timings)
                mergedTiming = obj.mergeDefaults( ...
                    timings(timingIx),defaultTiming);
                normalizedTimings(timingIx) = orderfields( ...
                    mergedTiming,defaultTiming);
            end
            timings = normalizedTimings;
        end

        function runConfig = mergeDefaults(obj,runConfig,defaults) %#ok<INUSD>
            defaultFields = fieldnames(defaults);
            for i = 1:numel(defaultFields)
                fieldName = defaultFields{i};
                if ~isfield(runConfig,fieldName)
                    runConfig.(fieldName) = defaults.(fieldName);
                end
            end
        end

        function values = asCellstr(obj,values) %#ok<INUSD>
            if isstring(values)
                values = cellstr(values);
            elseif ischar(values)
                values = {values};
            end
        end

        function ensureFolders(obj)
            if ~isfolder(obj.rootPath)
                mkdir(obj.rootPath);
            end
            if ~isfolder(obj.cachePath)
                mkdir(obj.cachePath);
            end
        end

        function state = defaultState(obj)
            state = struct();
            state.createdAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            state.updatedAt = state.createdAt;
            state.currentStage = 'new';
            state.completedStages = {};
            state.history = {};
            state.stageTimings = obj.defaultStageTimings();
        end

        function tf = isStageComplete(obj,stageName)
            tf = any(strcmp(obj.state.completedStages,stageName));
        end

        function markStageComplete(obj,stageName)
            if ~obj.isStageComplete(stageName)
                obj.state.completedStages{end + 1} = stageName;
            end
            obj.markStateChange(stageName);
        end

        function markStateChange(obj,stageName)
            obj.state.currentStage = stageName;
            obj.state.updatedAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            obj.state.history{end + 1} = struct( ...
                'stage',stageName, ...
                'timestamp',obj.state.updatedAt);
        end

        function invalidateStages(obj,stageNames)
            keepStages = {};
            for i = 1:numel(obj.state.completedStages)
                if ~any(strcmp(stageNames,obj.state.completedStages{i}))
                    keepStages{end + 1} = obj.state.completedStages{i}; %#ok<AGROW>
                end
            end
            obj.state.completedStages = keepStages;
            obj.markStageTimingsStale(stageNames);
        end

        function saveState(obj)
            obj.ensureFolders();
            obj.state = obj.normalizeState(obj.state);
            obj.attachResultsPerformance();
            artifactFiles = obj.workflowArtifactFiles();
            paths = obj.workflowPaths();

            [workflowData,workflowResults] = obj.splitWorkflowData(obj.data);
            [workflowData,workflowDataMetadata] = ...
                planWorkflow.persistence.WorkflowDataArtifact.compactForSave( ...
                workflowData,obj.runConfig,obj.cachePath);
            dataMetadata = obj.artifactMetadata('data');
            dataMetadata.workflowData = workflowDataMetadata;
            dataArtifact = struct('data',workflowData, ...
                'dataMetadata',dataMetadata);
            dataSaveTelemetry = ...
                obj.saveStructArtifact(obj.dataFile,dataArtifact,'data');

            resultsArtifact = struct('results',workflowResults, ...
                'resultsMetadata',obj.artifactMetadata('results'));
            resultsSaveTelemetry = ...
                obj.saveStructArtifact(obj.resultsFile,resultsArtifact, ...
                'results');

            performance = obj.performanceSummary();
            artifactSaveTelemetry = struct();
            artifactSaveTelemetry.data = dataSaveTelemetry;
            artifactSaveTelemetry.results = resultsSaveTelemetry;
            performanceArtifact = struct( ...
                'performance',performance, ...
                'stageTimings',obj.state.stageTimings, ...
                'performanceMetadata',obj.artifactMetadata('performance'));
            artifactSaveTelemetry.performance = ...
                obj.pendingSaveTelemetry( ...
                'performance',obj.performanceFile,performanceArtifact);
            performanceArtifact.performance.artifactSaveTelemetry = ...
                artifactSaveTelemetry;
            performanceSaveTelemetry = ...
                obj.saveStructArtifact(obj.performanceFile,performanceArtifact, ...
                'performance');

            stateSnapshot = rmfield(obj.state,'stageTimings');
            manifest = struct( ...
                'runConfig',obj.runConfig, ...
                'stageConfig',obj.stageConfig, ...
                'state',stateSnapshot, ...
                'paths',paths, ...
                'className',class(obj), ...
                'artifactFiles',artifactFiles);
            manifest.artifactSaveTelemetry = artifactSaveTelemetry;
            manifest.artifactSaveTelemetry.performance = ...
                performanceSaveTelemetry;
            obj.saveStructArtifact(obj.stateFile,manifest,'state');
            obj.log(sprintf('Workflow state saved to %s.',obj.stateFile));
        end

        function telemetry = saveStructArtifact(obj,filePath,artifact,kind)
            if nargin < 4
                kind = '';
            end
            telemetry = obj.pendingSaveTelemetry(kind,filePath,artifact);
            saveTimer = tic;
            builtin('save',filePath,'-struct','artifact','-v7.3');
            telemetry.saveSeconds = toc(saveTimer);
            telemetry.fileBytes = obj.fileBytes(filePath);
            telemetry.savedAt = char(datetime('now','Format', ...
                'yyyy-MM-dd HH:mm:ss'));
        end

        function telemetry = pendingSaveTelemetry(~,kind,filePath,artifact)
            info = whos('artifact');
            telemetry = struct();
            telemetry.artifactKind = char(kind);
            telemetry.filePath = char(filePath);
            telemetry.saveSeconds = NaN;
            telemetry.fileBytes = NaN;
            telemetry.logicalBytes = info.bytes;
            telemetry.savedAt = '';
        end

        function bytes = fileBytes(~,filePath)
            bytes = NaN;
            info = dir(filePath);
            if ~isempty(info)
                bytes = info.bytes;
            end
        end

        function loadState(obj,stateFile)
            snapshot = load(stateFile,'runConfig','stageConfig','state', ...
                'paths','className','artifactFiles');
            obj.runConfig = snapshot.runConfig;
            obj.stageConfig = snapshot.stageConfig;
            obj.applyWorkflowPaths(snapshot.paths,snapshot.artifactFiles);
            obj.state = obj.loadWorkflowState(snapshot.state);
            obj.data = obj.loadWorkflowData();
        end

        function artifactFiles = workflowArtifactFiles(obj)
            if isempty(obj.stateFile)
                obj.stateFile = fullfile(obj.rootPath,'workflow_state.mat');
            end
            if isempty(obj.dataFile)
                obj.dataFile = fullfile(obj.rootPath,'workflow_data.mat');
            end
            if isempty(obj.resultsFile)
                obj.resultsFile = fullfile(obj.rootPath,'workflow_results.mat');
            end
            if isempty(obj.performanceFile)
                obj.performanceFile = fullfile(obj.rootPath,'workflow_performance.mat');
            end

            artifactFiles = struct();
            artifactFiles.state = obj.stateFile;
            artifactFiles.data = obj.dataFile;
            artifactFiles.results = obj.resultsFile;
            artifactFiles.performance = obj.performanceFile;
        end

        function paths = workflowPaths(obj)
            paths = struct('rootPath',obj.rootPath, ...
                'folderPath',{obj.folderPath}, ...
                'cachePath',obj.cachePath, ...
                'runId',obj.runId);
        end

        function metadata = artifactMetadata(obj,kind)
            metadata = struct();
            metadata.kind = kind;
            metadata.savedAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            metadata.runId = obj.runId;
            metadata.className = class(obj);
            metadata.stateFile = obj.stateFile;
        end

        function [data,results] = splitWorkflowData(~,data)
            results = struct();
            if isstruct(data) && isfield(data,'results')
                results = data.results;
                data = rmfield(data,'results');
            end
        end

        function applyWorkflowPaths(obj,paths,artifactFiles)
            obj.rootPath = char(paths.rootPath);
            obj.folderPath = paths.folderPath;
            obj.cachePath = char(paths.cachePath);
            obj.runId = char(paths.runId);
            obj.stateFile = char(artifactFiles.state);
            obj.dataFile = char(artifactFiles.data);
            obj.resultsFile = char(artifactFiles.results);
            obj.performanceFile = char(artifactFiles.performance);
        end

        function state = loadWorkflowState(obj,state)
            performanceSnapshot = load(obj.performanceFile,'stageTimings');
            state.stageTimings = performanceSnapshot.stageTimings;
            state = obj.normalizeState(state);
        end

        function data = loadWorkflowData(obj)
            dataSnapshot = load(obj.dataFile,'data','dataMetadata');
            data = dataSnapshot.data;
            dataMetadata = struct();
            if isfield(dataSnapshot,'dataMetadata')
                dataMetadata = dataSnapshot.dataMetadata;
            end
            data = ...
                planWorkflow.persistence.WorkflowDataArtifact.rehydrateAfterLoad( ...
                data,dataMetadata,obj.runConfig,obj.cachePath);

            resultsSnapshot = load(obj.resultsFile,'results');
            results = resultsSnapshot.results;
            if isstruct(results) && ~isempty(fieldnames(results))
                data.results = results;
            end
        end

        function text = formatResolution(obj,values) %#ok<INUSD>
            text = sprintf('%gx%gx%g',values(1),values(2),values(3));
        end

        function text = formatNumericKey(obj,values) %#ok<INUSD>
            values = values(:)';
            text = strjoin(arrayfun(@(v) sprintf('%g',v),values,'UniformOutput',false),'x');
        end

        function log(obj,message)
            try
                obj.matRadCfg.dispInfo('%s\n',message);
            catch
                fprintf('%s\n',message);
            end
            obj.reportGuiLog(message);
        end

        function logConsoleOnly(obj,message)
            try
                obj.matRadCfg.dispInfo('%s\n',message);
            catch
                fprintf('%s\n',message);
            end
        end

        function reportGuiStageStarted(obj,stageName)
            [stageIx,numStages] = obj.guiProgressStageIndex(stageName);
            if isempty(stageIx)
                return;
            end
            obj.callGuiProgressReporter('stageStarted',stageName, ...
                stageIx,numStages);
        end

        function reportGuiStageProgress(obj,stageName,fraction,message)
            obj.callGuiProgressReporter('stageProgress',stageName, ...
                fraction,message);
            obj.assertGuiExecutionNotStopped();
        end

        function reportGuiStageCompleted(obj,stageName,wallTimeSeconds)
            [stageIx,numStages] = obj.guiProgressStageIndex(stageName);
            if isempty(stageIx)
                return;
            end
            obj.callGuiProgressReporter('stageCompleted',stageName, ...
                stageIx,numStages,wallTimeSeconds);
        end

        function reportGuiStageFailed(obj,stageName,message)
            [stageIx,numStages] = obj.guiProgressStageIndex(stageName);
            if isempty(stageIx)
                return;
            end
            obj.callGuiProgressReporter('stageFailed',stageName, ...
                stageIx,numStages,message);
        end

        function reportGuiLog(obj,message)
            obj.callGuiProgressReporter('log',message);
        end

        function reportGuiResults(obj)
            if isfield(obj.data,'results')
                obj.configureGuiProgressReporter();
                obj.attachResultsPerformance();
                results = obj.data.results;
                obj.callGuiProgressReporter('showResults',results);
            end
        end

        function [stageIx,numStages] = guiProgressStageIndex(obj,stageName)
            stages = obj.stageOrder();
            stageIx = find(strcmp(stageName,stages),1);
            numStages = numel(stages);
        end

        function callGuiProgressReporter(obj,action,varargin)
            reporter = obj.guiProgressReporter;
            if isempty(reporter)
                return;
            end

            try
                if isa(reporter,'handle') && ~isvalid(reporter)
                    return;
                end
            catch
            end

            try
                switch action
                    case 'stageStarted'
                        reporter.stageStarted(varargin{:});
                    case 'stageProgress'
                        reporter.stageProgress(varargin{:});
                    case 'stageCompleted'
                        reporter.stageCompleted(varargin{:});
                    case 'stageFailed'
                        reporter.stageFailed(varargin{:});
                    case 'log'
                        reporter.log(varargin{:});
                    case 'showResults'
                        reporter.showResults(varargin{:});
                end
            catch
            end
        end

        function assertGuiExecutionNotStopped(obj)
            reporter = obj.guiProgressReporter;
            if isempty(reporter)
                return;
            end

            try
                if isa(reporter,'handle') && ~isvalid(reporter)
                    return;
                end
            catch
            end

            try
                if ismethod(reporter,'isStopRequested') && ...
                        reporter.isStopRequested()
                    error('planWorkflow:gui:PlanProgressReporter:Stopped', ...
                        'Workflow execution was stopped from the interactive GUI.');
                end
            catch ME
                if strcmp(ME.identifier, ...
                        'planWorkflow:gui:PlanProgressReporter:Stopped')
                    rethrow(ME);
                end
            end
        end
    end

    methods (Abstract, Access = protected)
        runConfig = defaultRunConfig(obj)
        runConfig = normalizeRunConfig(obj,runConfig,varargin)
        configurePaths(obj)
        doPrepare(obj)
        doPrecompute(obj)
        doDosePulling(obj)
        doOptimize(obj)
        doSampling(obj)
        doAnalyze(obj)
    end
end
