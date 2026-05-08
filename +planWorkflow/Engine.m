classdef Engine < planWorkflow.WorkflowBase
    % Engine General robust optimization workflow implementation.

    methods
        function obj = Engine(config)
            if nargin < 1
                config = struct();
            end
            obj@planWorkflow.WorkflowBase(config);
        end
    end

    methods (Access = protected)
        function runConfig = defaultRunConfig(obj)
            runConfig = struct();
            runConfig.workflowType = 'robust';
            runConfig.radiationMode = 'photons';
            runConfig.description = 'prostate';
            runConfig.caseID = '3482';
            runConfig.AcquisitionType = 'dicom';
            runConfig.dicomMetadata = struct();
            runConfig.doseResolution = [5 5 5];
            runConfig.hlutFileName = 'matRad_default.hlut';
            runConfig.machine = '';
            runConfig.bioModel = '';
            runConfig.quantityOpt = '';
            runConfig.plan_template = 'interval2_001';
            runConfig.plan_template_hash = '';
            runConfig.plan_beams = '';
            runConfig.precompute = ...
                planWorkflow.config.RobustPlanConfig.defaults();
            runConfig.skinMode = 'full';
            runConfig.skinThicknessMm = [];
            runConfig.skinTargetDistanceMm = 30;
            runConfig.optimizer = 'IPOPT';
            dosePullingDefaults = ...
                planWorkflow.config.DosePullingConfig.defaults();
            dosePullingFields = fieldnames(dosePullingDefaults);
            for i = 1:numel(dosePullingFields)
                fieldName = dosePullingFields{i};
                runConfig.(fieldName) = dosePullingDefaults.(fieldName);
            end
            runConfig.sampling_caseID = 'none';
            runConfig.sampling_AcquisitionType = 'none';
            runConfig.sampling_dicomMetadata = struct();
            runConfig.sampling_linkToOptimization = true;
            samplingScenario = ...
                planWorkflow.config.ScenarioSpec.defaults( ...
                'impScen_permuted5');
            samplingScenario.wcSigma = 1.5;
            runConfig = planWorkflow.config.ScenarioSpec.applyToRunConfig( ...
                runConfig,'sampling',samplingScenario);
            runConfig.resolution = [3 3 3];
            runConfig.analysis = planWorkflow.config.Analysis.defaults();
            runConfig.useCache = true;
            runConfig.writeCache = true;
            runConfig.runId = '';
            runConfig.rootPath = obj.matRadCfg.primaryUserFolder;
            runConfig.outputRootPath = '';
            runConfig.patientDataPath = '';
            runConfig.cacheRootPath = '';
            runConfig.n_cores = feature('numcores');
        end

        function runConfig = normalizeRunConfig(obj,runConfig,effectiveTemplate)
            if nargin < 3
                effectiveTemplate = [];
            end
            obj.rejectUnsupportedConfigFields(runConfig);

            runConfig.radiationMode = char(runConfig.radiationMode);
            supportedRadiationModes = ...
                planWorkflow.matRadCapabilitiesReader.supportedRadiationModes();
            if ~any(strcmp(runConfig.radiationMode,supportedRadiationModes))
                error('planWorkflow:Engine:InvalidRadiationMode', ...
                    ['This workflow supports the installed matRad radiation ' ...
                     'modes: %s.'],strjoin(supportedRadiationModes,', '));
            end

            runConfig.description = char(runConfig.description);
            runConfig.caseID = char(runConfig.caseID);
            runConfig.AcquisitionType = char(runConfig.AcquisitionType);
            runConfig.workflowType = char(runConfig.workflowType);
            hasRawRobustPlans = isfield(runConfig.precompute,'robustPlans');
            if hasRawRobustPlans
                rawRobustPlans = runConfig.precompute.robustPlans;
                runConfig.precompute = rmfield( ...
                    runConfig.precompute,'robustPlans');
            end
            runConfig.precompute = ...
                planWorkflow.config.RobustPlanConfig.normalizePrecompute( ...
                runConfig.precompute);
            if hasRawRobustPlans
                runConfig.precompute.robustPlans = rawRobustPlans;
            end
            runConfig.plan_template = ...
                planWorkflow.templates.PlanTemplate.normalizeTemplateId( ...
                runConfig.description,runConfig.plan_template);
            runConfig.plan_template_hash = char(runConfig.plan_template_hash);
            runConfig.plan_beams = char(runConfig.plan_beams);
            if isempty(effectiveTemplate)
                template = planWorkflow.templates.PlanTemplate.loadForDescription( ...
                    runConfig.description,runConfig.plan_template);
            else
                template = effectiveTemplate;
            end
            if isempty(runConfig.plan_beams)
                runConfig.plan_beams = ...
                    planWorkflow.templates.PlanTemplate.defaultBeamSetForRadiationMode( ...
                    template,runConfig.radiationMode);
            end
            if ~isfield(runConfig,'machine') || isempty(runConfig.machine)
                runConfig.machine = ...
                    planWorkflow.templates.PlanTemplate.defaultMachineForRadiationMode( ...
                    template,runConfig.radiationMode);
            end
            runConfig.machine = char(runConfig.machine);
            if ~isfield(runConfig,'bioModel') || isempty(runConfig.bioModel)
                runConfig.bioModel = ...
                    planWorkflow.templates.PlanTemplate.defaultBioModelForRadiationMode( ...
                    template,runConfig.radiationMode);
            end
            runConfig.bioModel = char(runConfig.bioModel);
            planWorkflow.templates.PlanTemplate.validateRunConfigSelection( ...
                runConfig,template);
            runConfig = ...
                planWorkflow.config.WorkflowContractValidator.alignRobustPlansWithTemplate( ...
                runConfig,template);
            obj.validateRadiationModeOption( ...
                runConfig.machine, ...
                planWorkflow.matRadCapabilitiesReader.supportedMachines( ...
                runConfig.radiationMode), ...
                'machine',runConfig.radiationMode);
            obj.validateRadiationModeOption( ...
                runConfig.bioModel, ...
                planWorkflow.matRadCapabilitiesReader.supportedBioModels( ...
                runConfig.radiationMode), ...
                'bioModel',runConfig.radiationMode);
            runConfig = ...
                planWorkflow.plan.DoseQuantityResolver.applyDefaultToRunConfig( ...
                runConfig,false);
            runConfig.skinMode = char(runConfig.skinMode);
            runConfig.optimizer = char(runConfig.optimizer);
            runConfig.sampling_caseID = char(runConfig.sampling_caseID);
            runConfig.sampling_AcquisitionType = char(runConfig.sampling_AcquisitionType);
            runConfig.sampling_linkToOptimization = ...
                obj.scalarLogicalValue(runConfig.sampling_linkToOptimization, ...
                'sampling_linkToOptimization');
            runConfig.sampling_scen_mode = char(runConfig.sampling_scen_mode);
            samplingScenario = ...
                planWorkflow.config.ScenarioSpec.fromRunConfig( ...
                runConfig,'sampling');
            samplingScenario = ...
                planWorkflow.config.ScenarioSpec.normalize( ...
                samplingScenario,samplingScenario, ...
                'sampling.scenario');
            runConfig = planWorkflow.config.ScenarioSpec.applyToRunConfig( ...
                runConfig,'sampling',samplingScenario);
            referenceConfig = ...
                planWorkflow.config.RobustPlanConfig.referenceFromRunConfig( ...
                runConfig);
            planWorkflow.scenario.validateDimensionScales( ...
                planWorkflow.config.RobustPlanConfig.matRadScenario( ...
                referenceConfig.scenario));
            robustPlanConfigs = ...
                planWorkflow.config.RobustPlanConfig.plansFromRunConfig( ...
                runConfig);
            for robustPlanIx = 1:numel(robustPlanConfigs)
                planWorkflow.scenario.validateDimensionScales( ...
                    planWorkflow.config.RobustPlanConfig.matRadScenario( ...
                    robustPlanConfigs(robustPlanIx).scenario));
            end
            planWorkflow.scenario.validateDimensionScales( ...
                planWorkflow.config.ScenarioSpec.matRadScenario( ...
                planWorkflow.config.ScenarioSpec.fromRunConfig( ...
                runConfig,'sampling')));
            if ~isstruct(runConfig.dicomMetadata) || ~isscalar(runConfig.dicomMetadata)
                error('planWorkflow:Engine:InvalidDicomMetadata', ...
                    'dicomMetadata must be a scalar struct.');
            end
            if ~isstruct(runConfig.sampling_dicomMetadata) || ...
                    ~isscalar(runConfig.sampling_dicomMetadata)
                error('planWorkflow:Engine:InvalidDicomMetadata', ...
                    'sampling_dicomMetadata must be a scalar struct.');
            end
            runConfig.analysis = ...
                planWorkflow.config.Analysis.normalize(runConfig.analysis);
            runConfig = ...
                planWorkflow.config.DosePullingConfig.applyDefaults( ...
                runConfig);
            runConfig.dose_pulling1_target = obj.asCellstr(runConfig.dose_pulling1_target);
            runConfig.dose_pulling1_criteria = obj.asCellstr(runConfig.dose_pulling1_criteria);
            runConfig.dose_pulling2_target = obj.asCellstr(runConfig.dose_pulling2_target);
            runConfig.dose_pulling2_criteria = char(runConfig.dose_pulling2_criteria);
            runConfig = ...
                planWorkflow.config.DosePullingConfig.normalizeSearchConfig( ...
                runConfig);

            if isempty(runConfig.outputRootPath)
                runConfig.outputRootPath = fullfile(obj.matRadCfg.primaryUserFolder,'output');
            end
            if isempty(runConfig.patientDataPath)
                runConfig.patientDataPath = fullfile(obj.matRadCfg.primaryUserFolder,'patients');
            end
            if isempty(runConfig.cacheRootPath)
                runConfig.cacheRootPath = fullfile(runConfig.outputRootPath,'cache');
            end
            if runConfig.sampling_linkToOptimization
                runConfig.sampling_caseID = runConfig.caseID;
                runConfig.sampling_AcquisitionType = runConfig.AcquisitionType;
                runConfig.sampling_dicomMetadata = runConfig.dicomMetadata;
            elseif strcmp(runConfig.sampling_caseID,'none')
                runConfig.sampling_caseID = runConfig.caseID;
            end
            if ~runConfig.sampling_linkToOptimization && ...
                    strcmp(runConfig.sampling_AcquisitionType,'none')
                runConfig.sampling_AcquisitionType = runConfig.AcquisitionType;
            end
        end

        function runConfig = expandRunConfig(obj,runConfig)
            groupNames = ...
                planWorkflow.config.StageConfigSchema.publicStageNames();

            for i = 1:numel(groupNames)
                groupName = groupNames{i};
                if ~isfield(runConfig,groupName)
                    continue;
                end

                stageName = ...
                    planWorkflow.config.StageConfigSchema.engineStageName( ...
                    groupName);
                stageConfig = runConfig.(groupName);
                if ~isstruct(stageConfig) || ~isscalar(stageConfig)
                    error('planWorkflow:Engine:InvalidStageConfigGroup', ...
                        'workflowConfig.%s must be a scalar struct.', ...
                        groupName);
                end
                runConfig = rmfield(runConfig,groupName);

                stageConfig = obj.normalizeStageConfig(stageName,stageConfig);
                obj.validateStageConfigFields(stageName,stageConfig);
                runPatch = obj.stageConfigToRunConfig(stageName,stageConfig);
                runConfig = obj.mergeExpandedRunPatch( ...
                    runConfig,runPatch,groupName);
            end
        end

        function runConfig = mergeExpandedRunPatch(obj,runConfig,patch,groupName)
            patchFields = fieldnames(patch);
            for i = 1:numel(patchFields)
                fieldName = patchFields{i};
                if isfield(runConfig,fieldName)
                    if isstruct(runConfig.(fieldName)) && ...
                            isstruct(patch.(fieldName)) && ...
                            isscalar(runConfig.(fieldName)) && ...
                            isscalar(patch.(fieldName))
                        runConfig.(fieldName) = ...
                            obj.mergeExpandedRunPatch( ...
                            runConfig.(fieldName),patch.(fieldName), ...
                            [groupName '.' fieldName]);
                    elseif ~isequaln(runConfig.(fieldName),patch.(fieldName))
                        error('planWorkflow:Engine:ConflictingStageConfig', ...
                            ['workflowConfig.%s conflicts with ' ...
                            'workflowConfig.%s. Use only one spelling.'], ...
                            groupName,fieldName);
                    end
                else
                    runConfig.(fieldName) = patch.(fieldName);
                end
            end
        end

        function rejectUnsupportedConfigFields(obj,runConfig)
            unsupportedFields = { ...
                'plan_target', ...
                'sampling', ...
                'sampling_mode', ...
                'doseWindow', ...
                'doseWindowDvh', ...
                'doseWindowUncertainty', ...
                'doseWindowRelativeUncertainty1', ...
                'doseWindowRelativeUncertainty2', ...
                'doseWindowUvh', ...
                'gammaWindow', ...
                'gammaCriteria', ...
                'robustnessCriteria', ...
                'robustnessTargetMode', ...
                'robustnessTargets', ...
                'robustness', ...
                'robustPlans', ...
                'robust_scen_mode', ...
                'p1','p2','theta1','theta2', ...
                'KMode','kmax','retentionThreshold'};
            replacements = { ...
                'objectives.json target', ...
                'workflow.sample()', ...
                'sampling_scen_mode', ...
                'analysis.doseWindow', ...
                'analysis.doseWindowDvh', ...
                'analysis.doseWindowUncertainty', ...
                'analysis.doseWindowRelativeUncertainty1', ...
                'analysis.doseWindowRelativeUncertainty2', ...
                'analysis.doseWindowUvh', ...
                'analysis.gammaWindow', ...
                'analysis.gammaCriteria', ...
                'analysis.robustnessCriteria', ...
                'analysis.robustnessTargetMode', ...
                'analysis.robustnessTargets', ...
                'objectives.properties.robustness', ...
                'precompute.robustPlans', ...
                'precompute.robustPlans(i).scenario.mode', ...
                'precompute.robustPlans(i).variants(j).p1', ...
                'precompute.robustPlans(i).variants(j).p2', ...
                'precompute.robustPlans(i).variants(j).theta1', ...
                'precompute.robustPlans(i).variants(j).theta2', ...
                'precompute.robustPlans(i).robustnessOptions.KMode', ...
                'precompute.robustPlans(i).robustnessOptions.kmax', ...
                'precompute.robustPlans(i).robustnessOptions.retentionThreshold'};

            for i = 1:numel(unsupportedFields)
                if isfield(runConfig,unsupportedFields{i})
                    error('planWorkflow:Engine:UnsupportedConfigField', ...
                        'Unsupported config field "%s". Use "%s" instead.', ...
                        unsupportedFields{i},replacements{i});
                end
            end

            defaults = obj.defaultRunConfig();
            defaultFields = fieldnames(defaults);
            configFields = fieldnames(runConfig);
            for i = 1:numel(configFields)
                if ~isfield(defaults,configFields{i})
                    error('planWorkflow:Engine:UnsupportedConfigField', ...
                        'Unsupported config field "%s". Valid fields are: %s.', ...
                        configFields{i},strjoin(defaultFields',', '));
                end
            end
        end

        function fields = stageConfigFields(obj,stageName)
            fields = planWorkflow.config.StageConfigSchema.fields( ...
                planWorkflow.config.StageConfigSchema.publicName(stageName), ...
                planWorkflow.config.Analysis.defaults());
        end

        function stageConfig = normalizeStageConfig(obj,stageName,stageConfig)
            switch stageName
                case 'prepare'
                    charFields = {'radiationMode','description', ...
                        'caseID','AcquisitionType','hlutFileName', ...
                        'machine','bioModel','quantityOpt', ...
                        'plan_template','plan_beams', ...
                        'runId','rootPath','outputRootPath', ...
                        'patientDataPath','cacheRootPath'};
                    stageConfig = obj.charFields(stageConfig,charFields);
                case 'precompute'
                    if isfield(stageConfig,'reference')
                        stageConfig.reference = ...
                            planWorkflow.config.RobustPlanConfig.normalizeReference( ...
                            stageConfig.reference);
                    end
                case 'pullDose'
                    if isfield(stageConfig,'step1Target')
                        stageConfig.step1Target = obj.asCellstr(stageConfig.step1Target);
                    end
                    if isfield(stageConfig,'step1Criteria')
                        stageConfig.step1Criteria = obj.asCellstr(stageConfig.step1Criteria);
                    end
                    if isfield(stageConfig,'step2Criteria')
                        stageConfig.step2Criteria = char(stageConfig.step2Criteria);
                    end
                    if isfield(stageConfig,'step2Target')
                        stageConfig.step2Target = obj.asCellstr(stageConfig.step2Target);
                    end
                case 'optimize'
                    if isfield(stageConfig,'optimizer')
                        stageConfig.optimizer = char(stageConfig.optimizer);
                    end
                case 'sample'
                    stageConfig = obj.normalizeSamplingStageConfig(stageConfig);
                    charFields = {'caseID','AcquisitionType', ...
                        'sampling_scen_mode'};
                    stageConfig = obj.charFields(stageConfig,charFields);
                case 'analyze'
                    runConfigForAnalysis = obj.runConfig;
                    runConfigForAnalysis.analysis = ...
                        planWorkflow.config.Analysis.normalize(stageConfig);
                    stageConfig = ...
                        planWorkflow.analysis.AnalysisService.completeConfig( ...
                        runConfigForAnalysis,obj.data);
            end
        end

        function runConfig = stageConfigToRunConfig(obj,stageName,stageConfig)
            publicStageName = ...
                planWorkflow.config.StageConfigSchema.publicName(stageName);
            switch stageName
                case 'sample'
                    stageConfig = obj.normalizeSamplingStageConfig(stageConfig);
                    runConfig = ...
                        planWorkflow.config.StageConfigSchema.mapToRunConfig( ...
                        publicStageName,stageConfig);
                    geometryFields = {'caseID','AcquisitionType', ...
                        'dicomMetadata','sampling_dicomMetadata'};
                    usesExplicitGeometry = any(isfield( ...
                        stageConfig,geometryFields));
                    if usesExplicitGeometry && ...
                            ~isfield(runConfig,'sampling_linkToOptimization')
                        runConfig.sampling_linkToOptimization = false;
                    end
                case 'analyze'
                    runConfig.analysis = stageConfig;
                otherwise
                    runConfig = ...
                        planWorkflow.config.StageConfigSchema.mapToRunConfig( ...
                        publicStageName,stageConfig);
            end
        end

        function configurePaths(obj)
            if isempty(obj.runConfig.runId)
                obj.runId = char(datetime('now','Format','yyyy-MM-dd_HH-mm-ss'));
                obj.runConfig.runId = obj.runId;
            else
                obj.runId = char(obj.runConfig.runId);
            end

            workflowIdentity = ...
                planWorkflow.results.WorkflowIdentity.fromRunConfig( ...
                obj.runConfig);
            obj.rootPath = ...
                planWorkflow.results.WorkflowIdentity.rootPath( ...
                obj.runConfig);
            obj.data.workflowIdentity = workflowIdentity;
            obj.folderPath = {obj.rootPath};
            obj.cachePath = obj.runConfig.cacheRootPath;
            obj.stateFile = fullfile(obj.rootPath,'workflow_state.mat');
            obj.dataFile = fullfile(obj.rootPath,'workflow_data.mat');
            obj.resultsFile = fullfile(obj.rootPath,'workflow_results.mat');
            obj.performanceFile = fullfile(obj.rootPath,'workflow_performance.mat');
        end

        function beforePrepareStage(obj)
            obj.prepareEffectivePlanTemplate();
        end

        function progressReporter = doGui(obj)
            progressReporter = obj.openInteractivePlanEditorStage();
        end

        function doPrepare(obj)
            obj.executePrepareStage();
        end

        function executePrepareStage(obj)
            obj.executeStage('prepare');
        end

        function doPrecompute(obj)
            obj.executePrecomputeStage();
        end

        function executePrecomputeStage(obj)
            obj.executeStage('precompute');
        end

        function doDosePulling(obj)
            obj.executeDosePullingStage();
        end

        function executeDosePullingStage(obj)
            obj.executeStage('pullDose');
        end

        function doOptimize(obj)
            obj.executeOptimizeStage();
        end

        function executeOptimizeStage(obj)
            obj.executeStage('optimize');
        end

        function doSampling(obj)
            obj.executeSamplingStage();
        end

        function executeSamplingStage(obj)
            obj.executeStage('sample');
        end

        function doAnalyze(obj)
            obj.executeAnalyzeStage();
        end

        function executeAnalyzeStage(obj)
            obj.executeStage('analyze');
        end
    end

    methods (Access = protected)
        function executeStage(obj,stageName)
            patch = planWorkflow.stages.StageExecutor.run( ...
                stageName,obj.runConfig,obj.data,obj.workflowRuntime());
            if isfield(patch,'data') && isfield(patch.data,'results') && ...
                    isstruct(patch.data.results)
                patch.data.results.performance = obj.performanceSummary();
            end
            obj.applyStagePatch(patch);
        end

        function runtime = workflowRuntime(obj)
            runtime = planWorkflow.stages.WorkflowRuntime( ...
                obj.measuredTaskRunner(), ...
                @(message) obj.log(message), ...
                @(stageNameIn,fraction,message) ...
                obj.reportGuiStageProgress(stageNameIn,fraction,message));
        end

        function taskRunner = measuredTaskRunner(obj)
            taskRunner = @(stageNameIn,role,label,taskName, ...
                robustPlanId,variantId,taskFunction) ...
                obj.runMeasuredPlanTask(stageNameIn,role,label,taskName, ...
                robustPlanId,variantId,taskFunction);
        end

        function applyStagePatch(obj,patch)
            if ~isstruct(patch) || isempty(patch)
                return;
            end
            if isfield(patch,'runConfig') && isstruct(patch.runConfig)
                obj.runConfig = obj.applyShallowPatch(obj.runConfig, ...
                    patch.runConfig);
            end
            if isfield(patch,'data') && isstruct(patch.data)
                obj.data = obj.applyShallowPatch(obj.data,patch.data);
            end
        end

        function output = applyShallowPatch(obj,output,patch) %#ok<INUSD>
            fields = fieldnames(patch);
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                output.(fieldName) = patch.(fieldName);
            end
        end

        function config = charFields(obj,config,fieldNames) %#ok<INUSD>
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                if isfield(config,fieldName)
                    config.(fieldName) = char(config.(fieldName));
                end
            end
        end

        function value = scalarLogicalValue(obj,value,fieldName) %#ok<INUSD>
            if ischar(value) || (isstring(value) && isscalar(value))
                switch lower(char(value))
                    case {'true','1','yes','on'}
                        value = true;
                    case {'false','0','no','off'}
                        value = false;
                    otherwise
                        error('planWorkflow:Engine:InvalidLogicalField', ...
                            'Field "%s" must be scalar logical.',fieldName);
                end
            else
                value = logical(value);
            end

            if ~isscalar(value)
                error('planWorkflow:Engine:InvalidLogicalField', ...
                    'Field "%s" must be scalar logical.',fieldName);
            end
        end

        function value = positiveIntegerScalar(obj,value,fieldName) %#ok<INUSD>
            valid = isnumeric(value) && isscalar(value) && ...
                isfinite(value) && value >= 1 && round(value) == value;
            if ~valid
                error('planWorkflow:Engine:InvalidPositiveIntegerField', ...
                    'Field "%s" must be a positive integer scalar.', ...
                fieldName);
            end
        end

        function value = optionalNonnegativeIntegerScalar(obj,value, ...
                fieldName) %#ok<INUSD>
            if isempty(value)
                value = [];
                return;
            end
            valid = isnumeric(value) && isscalar(value) && ...
                isfinite(value) && value >= 0 && round(value) == value;
            if ~valid
                error('planWorkflow:Engine:InvalidOptionalRandomSeed', ...
                    ['Field "%s" must be empty or a non-negative ' ...
                     'integer scalar.'],fieldName);
            end
        end

        function validateRadiationModeOption(obj,value,options,fieldName, ...
                radiationMode) %#ok<INUSD>
            if ~any(strcmp(char(value),options))
                error('planWorkflow:Engine:InvalidRadiationModeOption', ...
                    ['%s "%s" is not available for radiationMode "%s". ' ...
                     'Available values are: %s.'],fieldName,char(value), ...
                    char(radiationMode),strjoin(options,', '));
            end
        end

        function label = planTimingLabel(obj,label,role,robustPlanId, ...
                variantId)
            label = planWorkflow.results.PlanLabels.planTimingLabel( ...
                obj.runConfig,label,role,robustPlanId,variantId);
        end

        function stageConfig = normalizeSamplingStageConfig(obj,stageConfig)
            obj.assertSameSamplingAlias(stageConfig,'dicomMetadata','sampling_dicomMetadata');
            obj.assertSameSamplingAlias(stageConfig,'linkToOptimization', ...
                'sampling_linkToOptimization');
        end

        function assertSameSamplingAlias(obj,stageConfig,aliasField,explicitField) %#ok<INUSD>
            if ~isfield(stageConfig,aliasField) || ~isfield(stageConfig,explicitField)
                return;
            end

            aliasValue = stageConfig.(aliasField);
            explicitValue = stageConfig.(explicitField);
            if isempty(aliasValue) || isempty(explicitValue)
                return;
            end

            if (ischar(aliasValue) || isstring(aliasValue)) && ...
                    (ischar(explicitValue) || isstring(explicitValue))
                isSame = strcmp(char(aliasValue),char(explicitValue));
            else
                isSame = isequaln(aliasValue,explicitValue);
            end

            if ~isSame
                error('planWorkflow:Engine:ConflictingSamplingConfig', ...
                    ['Sampling config fields "%s" and "%s" refer to the same ' ...
                     'setting but contain different values.'], ...
                    aliasField,explicitField);
            end
        end

        function prepareEffectivePlanTemplate(obj)
            obj.setEffectivePlanTemplate(obj.activePlanTemplate());
        end

        function progressReporter = openInteractivePlanEditorStage(obj)
            template = obj.activePlanTemplate();
            options = obj.planEditorOptions();
            [template,runConfig,accepted,progressReporter,resumeStateFile] = ...
                obj.openInteractivePlanEditor(template,obj.runConfig, ...
                options);
            if ~accepted
                progressReporter = [];
                obj.log('Interactive plan editor closed by the user.');
                return;
            end

            if ~isempty(resumeStateFile)
                obj.resume(resumeStateFile);
                return;
            end

            if options.readOnly
                return;
            end

            obj.runConfig = obj.normalizeRunConfig(runConfig,template);
            obj.setEffectivePlanTemplate(template);
        end

        function options = planEditorOptions(obj)
            options = struct();
            options.readOnly = ~isempty(obj.state.completedStages);
            options.stateFile = obj.stateFile;
            options.rootPath = obj.rootPath;
            options.currentStage = obj.state.currentStage;
            options.completedStages = obj.state.completedStages;
            options.nextStage = obj.nextIncompleteStage();
            options.validateRunConfig = @(editedRunConfig,editedTemplate) ...
                obj.normalizeRunConfig(editedRunConfig,editedTemplate);
            options.recalculateAnalysisCallback = ...
                @(varargin) obj.recalculateAnalysis(varargin{:});
            options.progressReporterReadyCallback = ...
                @(progressReporter) obj.configureGuiProgressReporter( ...
                progressReporter);
            if obj.isStageComplete(obj.completedNameForStage('analyze')) && ...
                    isstruct(obj.data) && isfield(obj.data,'results')
                initialResults = obj.data.results;
                if isstruct(initialResults)
                    initialResults.performance = obj.performanceSummary();
                end
                options.initialResults = initialResults;
            end
        end

        function setEffectivePlanTemplate(obj,template)
            planWorkflow.templates.PlanTemplate.validateEffectiveTemplate( ...
                template,obj.runConfig);
            obj.runConfig.plan_template_hash = ...
                planWorkflow.templates.PlanTemplate.hash(template);
            obj.configurePaths();
            obj.stageConfig.prepare.plan_beams = obj.runConfig.plan_beams;
            obj.data.planTemplate = template;
            obj.data.planTemplateHash = obj.runConfig.plan_template_hash;
        end

        function [template,runConfig,accepted,progressReporter, ...
                resumeStateFile] = openInteractivePlanEditor( ...
                obj,template,runConfig,options) %#ok<INUSD>
            [template,runConfig,accepted,progressReporter,resumeStateFile] = ...
                planWorkflow.gui.PlanEditor.edit( ...
                template,runConfig,options);
        end

        function template = activePlanTemplate(obj)
            if isfield(obj.data,'planTemplate') && ...
                    ~isempty(obj.data.planTemplate)
                template = obj.data.planTemplate;
            else
                template = planWorkflow.templates.PlanTemplate.resolve( ...
                    obj.runConfig);
            end
        end
    end
end
