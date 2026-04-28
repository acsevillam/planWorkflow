classdef (Abstract) WorkflowBase < handle
    % WorkflowBase Base class for staged planWorkflow workflows.
    %
    % Subclasses implement the clinical/domain-specific steps while this
    % class owns the common lifecycle, state persistence, cache handling,
    % resume support, and console output.

    properties
        runConfig
        stageConfig
        data
        state
        strategy
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

            if isfield(obj.runConfig,'robustness')
                strategyName = obj.runConfig.robustness;
            else
                strategyName = 'none';
            end

            obj.strategy = obj.resolveStrategy(strategyName);
            obj.configurePaths();
        end

        function configure(obj,varargin)
            if isempty(varargin)
                return;
            end

            previousRunConfig = obj.runConfig;
            patch = obj.parseConfigArguments(varargin{:});
            obj.runConfig = obj.mergeStruct(obj.runConfig,patch);
            obj.runConfig = obj.normalizeRunConfig(obj.runConfig);
            obj.strategy = obj.resolveStrategy(obj.runConfig.robustness);
            obj.configurePaths();

            if ~isequaln(previousRunConfig,obj.runConfig)
                obj.invalidateStages(obj.stageCompletedNames('prepare'));
                obj.markStateChange('config:global');
            end
        end

        function prepare(obj,varargin)
            obj.configureStage('prepare',varargin{:});

            if obj.isStageComplete('prepared')
                obj.log('Workflow is already prepared.');
                return;
            end

            obj.ensureFolders();
            obj.runMeasuredStage('prepare','prepared',@() obj.doPrepare());
            obj.markStageComplete('prepared');
            obj.saveState();
        end

        function precompute(obj,varargin)
            obj.configureStage('precompute',varargin{:});

            if ~obj.isStageComplete('prepared')
                obj.prepare();
            end

            if obj.isStageComplete('precomputed')
                obj.log('Workflow is already precomputed.');
                return;
            end

            obj.ensureFolders();
            obj.runMeasuredStage('precompute','precomputed',@() obj.doPrecompute());
            obj.markStageComplete('precomputed');
            obj.saveState();
        end

        function optimize(obj,varargin)
            obj.configureStage('optimize',varargin{:});

            if ~obj.isStageComplete('dose_pulled')
                obj.pullDose();
            end

            if obj.isStageComplete('optimized')
                obj.log('Workflow is already optimized.');
                return;
            end

            obj.runMeasuredStage('optimize','optimized',@() obj.doOptimize());
            obj.markStageComplete('optimized');
            obj.saveState();
        end

        function pullDose(obj,varargin)
            obj.configureStage('pullDose',varargin{:});

            if ~obj.isStageComplete('precomputed')
                obj.precompute();
            end

            if obj.isStageComplete('dose_pulled')
                obj.log('Workflow dose pulling is already complete.');
                return;
            end

            obj.runMeasuredStage('pullDose','dose_pulled',@() obj.doDosePulling());
            obj.invalidateStages({'optimized','sampled','analyzed'});
            obj.markStageComplete('dose_pulled');
            obj.saveState();
        end

        function sample(obj,varargin)
            obj.configureStage('sample',varargin{:});

            if ~obj.isStageComplete('optimized')
                obj.optimize();
            end

            if obj.isStageComplete('sampled')
                obj.log('Workflow is already sampled.');
                return;
            end

            obj.runMeasuredStage('sample','sampled',@() obj.doSampling());
            obj.invalidateStages({'analyzed'});
            obj.markStageComplete('sampled');
            obj.saveState();
        end

        function analyze(obj,varargin)
            obj.configureStage('analyze',varargin{:});

            if ~obj.isStageComplete('optimized')
                obj.optimize();
            end

            if obj.isStageComplete('analyzed')
                obj.log('Workflow is already analyzed.');
                return;
            end

            obj.runMeasuredStage('analyze','analyzed',@() obj.doAnalyze());
            obj.markStageComplete('analyzed');
            obj.saveState();
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

        function setStrategy(obj,strategyName)
            obj.runConfig.robustness = char(strategyName);
            obj.strategy = obj.resolveStrategy(obj.runConfig.robustness);
            obj.invalidateStages({'precomputed','dose_pulled','optimized','sampled','analyzed'});
            obj.configurePaths();
            obj.markStateChange(sprintf('strategy:%s',obj.strategy.name));
            obj.saveState();
        end

        function cacheFile = getCacheFile(obj,tag)
            cacheKey = obj.buildCacheKey(tag);
            cacheFile = fullfile(obj.cachePath,[cacheKey '.mat']);
        end

        function tf = hasCache(obj,tag)
            tf = isfile(obj.getCacheFile(tag));
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
            stageName = char(stageName);
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
            obj.strategy = obj.resolveStrategy(obj.runConfig.robustness);
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
            stages = {'prepare','precompute','pullDose','optimize', ...
                'sample','analyze'};
        end

        function stageNames = stageCompletedNames(obj,stageName)
            stages = obj.stageOrder();
            completed = {'prepared','precomputed','dose_pulled','optimized', ...
                'sampled','analyzed'};
            stageIx = find(strcmp(stageName,stages),1);
            stageNames = completed(stageIx:end);
        end

        function completedStageName = completedNameForStage(obj,stageName) %#ok<INUSD>
            stages = {'prepare','precompute','pullDose','optimize', ...
                'sample','analyze'};
            completed = {'prepared','precomputed','dose_pulled','optimized', ...
                'sampled','analyzed'};
            stageIx = find(strcmp(stageName,stages),1);
            if isempty(stageIx)
                error('planWorkflow:WorkflowBase:UnknownStage', ...
                    'Unknown workflow stage "%s".',stageName);
            end
            completedStageName = completed{stageIx};
        end

        function stageName = stageNameFromCompleted(obj,completedStageName) %#ok<INUSD>
            stages = {'prepare','precompute','pullDose','optimize', ...
                'sample','analyze'};
            completed = {'prepared','precomputed','dose_pulled','optimized', ...
                'sampled','analyzed'};
            completedIx = find(strcmp(completedStageName,completed),1);
            if isempty(completedIx)
                stageName = '';
            else
                stageName = stages{completedIx};
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
            timing.lastStartDataMemoryBytes = NaN;
            timing.lastEndDataMemoryBytes = NaN;
            timing.lastDataMemoryDeltaBytes = NaN;
            timing.peakDataMemoryBytes = NaN;
            timing.memorySource = '';
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
            startProcessMemory = obj.processMemorySnapshot();
            startDataMemoryBytes = obj.matlabVariableBytes(obj.data);

            try
                stageFunction();
                memoryRecord = obj.stageMemoryRecord(startProcessMemory, ...
                    startDataMemoryBytes);
                obj.recordStageTiming(stageName,completedStageName,startTime, ...
                    toc(wallTimer),cputime - startCpuTime,'completed','', ...
                    memoryRecord);
            catch ME
                memoryRecord = obj.stageMemoryRecord(startProcessMemory, ...
                    startDataMemoryBytes);
                obj.recordStageTiming(stageName,completedStageName,startTime, ...
                    toc(wallTimer),cputime - startCpuTime,'failed', ...
                    ME.message,memoryRecord);
                obj.trySaveFailedStageState(stageName);
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
            record.startDataMemoryBytes = memoryRecord.startDataMemoryBytes;
            record.endDataMemoryBytes = memoryRecord.endDataMemoryBytes;
            record.dataMemoryDeltaBytes = memoryRecord.dataMemoryDeltaBytes;
            record.memorySource = memoryRecord.memorySource;

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
            timing.lastStartDataMemoryBytes = memoryRecord.startDataMemoryBytes;
            timing.lastEndDataMemoryBytes = memoryRecord.endDataMemoryBytes;
            timing.lastDataMemoryDeltaBytes = memoryRecord.dataMemoryDeltaBytes;
            timing.peakDataMemoryBytes = obj.maxFinite([ ...
                timing.peakDataMemoryBytes memoryRecord.endDataMemoryBytes]);
            timing.memorySource = memoryRecord.memorySource;
            timing.lastErrorMessage = errorMessage;
            timing.history{end + 1} = record;

            obj.state.stageTimings.(stageName) = timing;
        end

        function memoryRecord = stageMemoryRecord(obj,startProcessMemory, ...
                startDataMemoryBytes)
            endProcessMemory = obj.processMemorySnapshot();
            endDataMemoryBytes = obj.matlabVariableBytes(obj.data);
            memoryRecord = struct();
            memoryRecord.startProcessMemoryBytes = ...
                startProcessMemory.processMemoryBytes;
            memoryRecord.endProcessMemoryBytes = ...
                endProcessMemory.processMemoryBytes;
            memoryRecord.processMemoryDeltaBytes = ...
                obj.finiteDelta(memoryRecord.endProcessMemoryBytes, ...
                memoryRecord.startProcessMemoryBytes);
            memoryRecord.maxObservedProcessMemoryBytes = obj.maxFinite([ ...
                memoryRecord.startProcessMemoryBytes ...
                memoryRecord.endProcessMemoryBytes]);
            memoryRecord.startDataMemoryBytes = startDataMemoryBytes;
            memoryRecord.endDataMemoryBytes = endDataMemoryBytes;
            memoryRecord.dataMemoryDeltaBytes = obj.finiteDelta( ...
                endDataMemoryBytes,startDataMemoryBytes);
            memoryRecord.memorySource = endProcessMemory.source;
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

        function computationalResources = stageTimingSummary(obj)
            obj.state = obj.normalizeState(obj.state);
            computationalResources = struct();
            computationalResources.wallTimeUnit = 'seconds';
            computationalResources.cpuTimeUnit = 'seconds';
            computationalResources.memoryUnit = 'bytes';
            computationalResources.processMemoryMetric = ...
                'MATLAB process resident set size';
            computationalResources.dataMemoryMetric = ...
                'MATLAB bytes reported by whos for obj.data';
            computationalResources.stageTimings = obj.state.stageTimings;
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

        function dij = getOrCreateDoseInfluence(obj,tag,ct,cst,stf,pln)
            cacheFile = obj.getCacheFile(tag);
            if obj.runConfig.useCache && isfile(cacheFile)
                cached = load(cacheFile,'dij');
                if isfield(cached,'dij')
                    obj.log(sprintf('Loaded cached dij: %s.',cacheFile));
                    dij = cached.dij;
                    return;
                end
            end

            dij = matRad_calcDoseInfluence(ct,cst,stf,pln);
            if obj.runConfig.writeCache
                obj.ensureFolders();
                cacheMetadata = obj.cacheMetadata(tag,pln); %#ok<NASGU>
                builtin('save',cacheFile,'dij','cacheMetadata','-v7.3');
                obj.log(sprintf('Cached dij: %s.',cacheFile));
            end
        end

        function cacheKey = buildCacheKey(obj,tag)
            cacheParts = {tag};
            optionalFields = {'radiationMode','description','caseID','plan_target', ...
                'plan_beams','robustness','scen_mode'};
            for i = 1:numel(optionalFields)
                fieldName = optionalFields{i};
                if isfield(obj.runConfig,fieldName)
                    cacheParts{end + 1} = char(string(obj.runConfig.(fieldName))); %#ok<AGROW>
                end
            end
            numericFields = {'doseResolution','shiftSD','wcSigma', ...
                'rangeAbsSD','rangeRelSD','numOfRangeGridPoints'};
            for i = 1:numel(numericFields)
                fieldName = numericFields{i};
                if isfield(obj.runConfig,fieldName)
                    cacheParts{end + 1} = obj.formatNumericKey(obj.runConfig.(fieldName)); %#ok<AGROW>
                end
            end

            cacheKey = strjoin(cacheParts,'_');
            cacheKey = regexprep(cacheKey,'[^a-zA-Z0-9_-]','_');
        end

        function metadata = cacheMetadata(obj,tag,pln)
            metadata = struct();
            metadata.tag = tag;
            metadata.createdAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            metadata.runConfig = obj.runConfig;
            metadata.strategy = obj.strategy;
            if isfield(pln,'machine')
                metadata.machine = pln.machine;
            end
            metadata.className = class(obj);
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
            artifactFiles = obj.workflowArtifactFiles();
            paths = obj.workflowPaths();

            [workflowData,workflowResults] = obj.splitWorkflowData(obj.data);
            dataArtifact = struct('data',workflowData, ...
                'dataMetadata',obj.artifactMetadata('data'));
            obj.saveStructArtifact(obj.dataFile,dataArtifact);

            resultsArtifact = struct('results',workflowResults, ...
                'resultsMetadata',obj.artifactMetadata('results'));
            obj.saveStructArtifact(obj.resultsFile,resultsArtifact);

            performanceArtifact = struct( ...
                'computationalResources',obj.stageTimingSummary(), ...
                'stageTimings',obj.state.stageTimings, ...
                'performanceMetadata',obj.artifactMetadata('performance'));
            obj.saveStructArtifact(obj.performanceFile,performanceArtifact);

            stateSnapshot = rmfield(obj.state,'stageTimings');
            manifest = struct( ...
                'runConfig',obj.runConfig, ...
                'stageConfig',obj.stageConfig, ...
                'state',stateSnapshot, ...
                'strategy',obj.strategy, ...
                'paths',paths, ...
                'className',class(obj), ...
                'artifactFiles',artifactFiles);
            obj.saveStructArtifact(obj.stateFile,manifest);
            obj.log(sprintf('Workflow state saved to %s.',obj.stateFile));
        end

        function saveStructArtifact(~,filePath,artifact) %#ok<INUSD>
            builtin('save',filePath,'-struct','artifact','-v7.3');
        end

        function loadState(obj,stateFile)
            snapshot = load(stateFile,'runConfig','stageConfig','state', ...
                'strategy','paths','className','artifactFiles');
            obj.runConfig = snapshot.runConfig;
            obj.stageConfig = snapshot.stageConfig;
            obj.strategy = snapshot.strategy;
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
            dataSnapshot = load(obj.dataFile,'data');
            data = dataSnapshot.data;

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
        end
    end

    methods (Abstract, Access = protected)
        runConfig = defaultRunConfig(obj)
        runConfig = normalizeRunConfig(obj,runConfig)
        strategy = resolveStrategy(obj,strategyName)
        configurePaths(obj)
        doPrepare(obj)
        doPrecompute(obj)
        doDosePulling(obj)
        doOptimize(obj)
        doSampling(obj)
        doAnalyze(obj)
    end
end
