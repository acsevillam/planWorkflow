classdef Engine < robOpt.WorkflowBase
    % Engine General robust optimization workflow implementation.

    methods
        function obj = Engine(config)
            if nargin < 1
                config = struct();
            end
            obj@robOpt.WorkflowBase(config);
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
            runConfig.doseResolution = [5 5 5];
            runConfig.hlutFileName = 'matRad_default.hlut';
            runConfig.plan_objectives = '4';
            runConfig.plan_target = 'CTV';
            runConfig.plan_beams = '9F';
            runConfig.shiftSD = [5 10 5];
            runConfig.robustness = 'COWC';
            runConfig.scen_mode = 'wcScen';
            runConfig.wcSigma = 1.0;
            runConfig.rangeAbsSD = 0;
            runConfig.rangeRelSD = 0;
            runConfig.numOfRangeGridPoints = 1;
            runConfig.p1 = 1;
            runConfig.p2 = 1;
            runConfig.theta1 = 1.0;
            runConfig.theta2 = 1.0;
            runConfig.kdin = 'dinamic';
            runConfig.kmax = 10;
            runConfig.retentionThreshold = 0.95;
            runConfig.scale_factor = 1.0;
            runConfig.optimizer = 'IPOPT';
            runConfig.dose_pulling1 = false;
            runConfig.dose_pulling1_target = {'CTV'};
            runConfig.dose_pulling1_criteria = {'COV1'};
            runConfig.dose_pulling1_limit = 0.98;
            runConfig.dose_pulling1_start = 0;
            runConfig.dose_pulling2 = false;
            runConfig.dose_pulling2_criteria = 'meanQiTarget';
            runConfig.dose_pulling2_limit = 0.80;
            runConfig.dose_pulling2_start = 0;
            runConfig.dose_pulling_max_iter = 100;
            runConfig.sampling_caseID = 'none';
            runConfig.sampling_AcquisitionType = 'none';
            runConfig.sampling_scen_mode = 'impScen_permuted5';
            runConfig.sampling_wcSigma = 1.5;
            runConfig.sampling_size = 50;
            runConfig.resolution = [3 3 3];
            runConfig.analysis = obj.defaultAnalysisConfig();
            runConfig.useCache = true;
            runConfig.writeCache = true;
            runConfig.runId = '';
            runConfig.rootPath = obj.matRadCfg.primaryUserFolder;
            runConfig.outputRootPath = '';
            runConfig.patientDataPath = '';
            runConfig.cacheRootPath = '';
            runConfig.n_cores = feature('numcores');
        end

        function runConfig = normalizeRunConfig(obj,runConfig)
            obj.rejectUnsupportedConfigFields(runConfig);

            runConfig.radiationMode = char(runConfig.radiationMode);
            if ~any(strcmp(runConfig.radiationMode,{'photons','protons'}))
                error('robOpt:Engine:InvalidRadiationMode', ...
                    'This workflow supports photons and protons.');
            end

            runConfig.description = char(runConfig.description);
            runConfig.caseID = char(runConfig.caseID);
            runConfig.AcquisitionType = char(runConfig.AcquisitionType);
            runConfig.workflowType = char(runConfig.workflowType);
            runConfig.robustness = char(runConfig.robustness);
            runConfig.scen_mode = char(runConfig.scen_mode);
            runConfig.plan_objectives = char(runConfig.plan_objectives);
            runConfig.plan_target = char(runConfig.plan_target);
            runConfig.plan_beams = char(runConfig.plan_beams);
            runConfig.optimizer = char(runConfig.optimizer);
            runConfig.sampling_caseID = char(runConfig.sampling_caseID);
            runConfig.sampling_AcquisitionType = char(runConfig.sampling_AcquisitionType);
            runConfig.sampling_scen_mode = char(runConfig.sampling_scen_mode);
            runConfig.analysis = obj.normalizeAnalysisConfig(runConfig.analysis);
            runConfig.dose_pulling1_target = obj.asCellstr(runConfig.dose_pulling1_target);
            runConfig.dose_pulling1_criteria = obj.asCellstr(runConfig.dose_pulling1_criteria);
            runConfig.dose_pulling2_criteria = char(runConfig.dose_pulling2_criteria);

            if isempty(runConfig.outputRootPath)
                runConfig.outputRootPath = fullfile(obj.matRadCfg.primaryUserFolder,'output');
            end
            if isempty(runConfig.patientDataPath)
                runConfig.patientDataPath = fullfile(obj.matRadCfg.primaryUserFolder,'patients');
            end
            if isempty(runConfig.cacheRootPath)
                runConfig.cacheRootPath = fullfile(runConfig.outputRootPath,'cache');
            end
            if strcmp(runConfig.sampling_caseID,'none')
                runConfig.sampling_caseID = runConfig.caseID;
            end
            if strcmp(runConfig.sampling_AcquisitionType,'none')
                runConfig.sampling_AcquisitionType = runConfig.AcquisitionType;
            end
        end

        function strategy = resolveStrategy(obj,strategyName) %#ok<INUSD>
            strategyName = char(strategyName);
            switch strategyName
                case 'none'
                    strategy = robOpt.robustness.NoneStrategy();
                case 'STOCH'
                    strategy = robOpt.robustness.StochasticStrategy( ...
                        'STOCH',false);
                case 'STOCH2'
                    strategy = robOpt.robustness.StochasticStrategy( ...
                        'STOCH2',true);
                case 'COWC'
                    strategy = robOpt.robustness.COWCStrategy( ...
                        'COWC',false);
                case 'COWC2'
                    strategy = robOpt.robustness.COWCStrategy( ...
                        'COWC2',true);
                case 'c-COWC'
                    strategy = robOpt.robustness.CheapCOWCStrategy( ...
                        'c-COWC',false);
                case 'c-COWC2'
                    strategy = robOpt.robustness.CheapCOWCStrategy( ...
                        'c-COWC2',true);
                case {'INTERVAL1','INTERVAL2','INTERVAL3'}
                    strategy = robOpt.robustness.IntervalStrategy(strategyName);
                otherwise
                    error('robOpt:Engine:UnknownStrategy', ...
                        'Unknown robust optimization strategy: %s.',strategyName);
            end
        end

        function rejectUnsupportedConfigFields(obj,runConfig)
            unsupportedFields = { ...
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
                'robustnessCriteria'};
            replacements = { ...
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
                'analysis.robustnessCriteria'};

            for i = 1:numel(unsupportedFields)
                if isfield(runConfig,unsupportedFields{i})
                    error('robOpt:Engine:UnsupportedConfigField', ...
                        'Unsupported config field "%s". Use "%s" instead.', ...
                        unsupportedFields{i},replacements{i});
                end
            end

            defaults = obj.defaultRunConfig();
            defaultFields = fieldnames(defaults);
            configFields = fieldnames(runConfig);
            for i = 1:numel(configFields)
                if ~isfield(defaults,configFields{i})
                    error('robOpt:Engine:UnsupportedConfigField', ...
                        'Unsupported config field "%s". Valid fields are: %s.', ...
                        configFields{i},strjoin(defaultFields',', '));
                end
            end
        end

        function fields = stageConfigFields(obj,stageName)
            switch stageName
                case 'prepare'
                    fields = {'caseID','AcquisitionType','doseResolution', ...
                        'hlutFileName','plan_objectives','plan_target', ...
                        'plan_beams','shiftSD','resolution','runId', ...
                        'rootPath','outputRootPath','patientDataPath', ...
                        'cacheRootPath','n_cores'};
                case 'precompute'
                    fields = {'robustness','scen_mode','wcSigma', ...
                        'rangeAbsSD','rangeRelSD','numOfRangeGridPoints', ...
                        'p1','p2','theta1','theta2','kdin','kmax', ...
                        'retentionThreshold','scale_factor','useCache', ...
                        'writeCache'};
                case 'pullDose'
                    fields = {'step1Enabled','step1Target','step1Criteria', ...
                        'step1Limit','step1Start','step2Enabled', ...
                        'step2Criteria','step2Limit','step2Start', ...
                        'maxIterations'};
                case 'optimize'
                    fields = {'optimizer'};
                case 'sample'
                    fields = {'caseID','AcquisitionType','scen_mode', ...
                        'sampling_scen_mode','wcSigma','sampling_wcSigma', ...
                        'size','sampling_size'};
                case 'analyze'
                    fields = fieldnames(obj.defaultAnalysisConfig())';
                otherwise
                    fields = {};
            end
        end

        function stageConfig = normalizeStageConfig(obj,stageName,stageConfig)
            switch stageName
                case 'prepare'
                    charFields = {'caseID','AcquisitionType','hlutFileName', ...
                        'plan_objectives','plan_target','plan_beams','runId', ...
                        'rootPath','outputRootPath','patientDataPath', ...
                        'cacheRootPath'};
                    stageConfig = obj.charFields(stageConfig,charFields);
                case 'precompute'
                    charFields = {'robustness','scen_mode','kdin'};
                    stageConfig = obj.charFields(stageConfig,charFields);
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
                case 'optimize'
                    if isfield(stageConfig,'optimizer')
                        stageConfig.optimizer = char(stageConfig.optimizer);
                    end
                case 'sample'
                    stageConfig = obj.normalizeSamplingStageConfig(stageConfig);
                    charFields = {'caseID','AcquisitionType','scen_mode', ...
                        'sampling_scen_mode'};
                    stageConfig = obj.charFields(stageConfig,charFields);
                case 'analyze'
                    stageConfig = obj.completeAnalysisConfig(stageConfig);
            end
        end

        function runConfig = stageConfigToRunConfig(obj,stageName,stageConfig)
            runConfig = struct();
            switch stageName
                case {'prepare','precompute','optimize'}
                    runConfig = stageConfig;
                case 'pullDose'
                    runConfig = obj.mapStageFields(stageConfig,{ ...
                        'step1Enabled','dose_pulling1'; ...
                        'step1Target','dose_pulling1_target'; ...
                        'step1Criteria','dose_pulling1_criteria'; ...
                        'step1Limit','dose_pulling1_limit'; ...
                        'step1Start','dose_pulling1_start'; ...
                        'step2Enabled','dose_pulling2'; ...
                        'step2Criteria','dose_pulling2_criteria'; ...
                        'step2Limit','dose_pulling2_limit'; ...
                        'step2Start','dose_pulling2_start'; ...
                        'maxIterations','dose_pulling_max_iter'});
                case 'sample'
                    stageConfig = obj.normalizeSamplingStageConfig(stageConfig);
                    runConfig = obj.mapStageFields(stageConfig,{ ...
                        'caseID','sampling_caseID'; ...
                        'AcquisitionType','sampling_AcquisitionType'; ...
                        'scen_mode','sampling_scen_mode'; ...
                        'sampling_scen_mode','sampling_scen_mode'; ...
                        'wcSigma','sampling_wcSigma'; ...
                        'sampling_wcSigma','sampling_wcSigma'; ...
                        'size','sampling_size'; ...
                        'sampling_size','sampling_size'});
                case 'analyze'
                    runConfig.analysis = stageConfig;
            end
        end

        function configurePaths(obj)
            if isempty(obj.runConfig.runId)
                obj.runId = char(datetime('now','Format','yyyy-MM-dd_HH-mm-ss'));
                obj.runConfig.runId = obj.runId;
            else
                obj.runId = char(obj.runConfig.runId);
            end

            rootFolder = fullfile(obj.runConfig.radiationMode,obj.runConfig.description, ...
                obj.runConfig.caseID,obj.runConfig.workflowType,obj.strategy.name, ...
                obj.runConfig.plan_target,obj.runConfig.plan_beams, ...
                obj.runConfig.plan_objectives,obj.formatResolution(obj.runConfig.shiftSD), ...
                obj.runConfig.scen_mode,obj.runId);

            obj.rootPath = fullfile(obj.runConfig.outputRootPath,rootFolder);
            obj.folderPath = {obj.rootPath};
            obj.cachePath = fullfile(obj.runConfig.cacheRootPath, ...
                obj.runConfig.description,obj.runConfig.caseID);
            obj.stateFile = fullfile(obj.rootPath,'workflow_state.mat');
            obj.dataFile = fullfile(obj.rootPath,'workflow_data.mat');
            obj.resultsFile = fullfile(obj.rootPath,'workflow_results.mat');
            obj.performanceFile = fullfile(obj.rootPath,'workflow_performance.mat');
        end

        function doPrepare(obj)
            obj.log('Preparing robust workflow geometry, objectives, plan, and stf.');

            [ct,cst] = robOpt.io.loadGeometry(obj.runConfig,"optimization");
            cst = robOpt.structures.normalizeNames(cst,obj.runConfig);
            [ct,cst] = obj.ensureDeformationFields(ct,cst);
            [cst,objectiveInfo] = obj.prepareNominalObjectives(ct,cst);
            [pln,quantityOpt] = obj.createPlan(ct,cst);
            obj.setDoseWindows(objectiveInfo.prescriptionDose,pln);
            stf = matRad_generateStf(ct,cst,pln);

            obj.data.ct = ct;
            obj.data.cst = cst;
            obj.data.pln = pln;
            obj.data.stf = stf;
            obj.data.quantityOpt = quantityOpt;
            obj.data.objectiveInfo = objectiveInfo;
        end

        function doPrecompute(obj)
            obj.log('Precomputing nominal dose influence matrix.');
            obj.data.dij = obj.getOrCreateDoseInfluence( ...
                'nominal',obj.data.ct,obj.data.cst,obj.data.stf,obj.data.pln);

            if strcmp(obj.strategy.name,'none')
                return;
            end

            if obj.strategy.requiresIntervalDij()
                error('robOpt:Engine:IntervalPrecomputeMissing', ...
                    ['%s needs a concrete interval precompute implementation ' ...
                     'before it can be optimized in the staged workflow.'], ...
                    obj.strategy.name);
            end

            robustData = obj.prepareRobustData();
            [robustData.cst,robustData.pln] = obj.strategy.apply( ...
                robustData.cst,robustData.pln,robustData.objectiveInfo,obj.runConfig);

            obj.log(sprintf('Precomputing robust dose influence matrix for %s.',obj.strategy.name));
            robustData.dij = obj.getOrCreateDoseInfluence( ...
                ['robust_' obj.strategy.name],robustData.ct,robustData.cst, ...
                robustData.stf,robustData.pln);

            obj.data.robust = robustData;
        end

        function doDosePulling(obj)
            obj.data.dosePulling = struct();

            if ~obj.runConfig.dose_pulling1 && ~obj.runConfig.dose_pulling2
                obj.log('Dose pulling is disabled for this workflow.');
                return;
            end

            if obj.runConfig.dose_pulling1
                obj.log('Running dose pulling step 1 on nominal objectives.');
                [obj.data.cst,nominalReport] = obj.runNominalDosePulling( ...
                    obj.data.ct,obj.data.cst,obj.data.dij,obj.data.stf,obj.data.pln);
                obj.data.dosePulling.nominal = nominalReport;
                obj.logNominalDosePullingResults(nominalReport);

                if isfield(obj.data,'robust')
                    obj.data.robust = obj.refreshRobustDataAfterNominalPulling( ...
                        obj.data.robust);
                end
            end

            if obj.runConfig.dose_pulling2
                if ~isfield(obj.data,'robust')
                    error('robOpt:Engine:DosePullingNeedsRobustData', ...
                        'dose_pulling2 requires a robust optimization strategy.');
                end

                obj.log('Running dose pulling step 2 on robust objectives.');
                [obj.data.robust,robustReport] = obj.runRobustDosePulling( ...
                    obj.data.robust);
                obj.data.dosePulling.robust = robustReport;
                obj.logRobustDosePullingResults(robustReport);
            end
        end

        function doOptimize(obj)
            obj.log('Running nominal optimization.');
            obj.runConfig.analysis = obj.completeAnalysisConfig(obj.runConfig.analysis);
            nominalInitialWeights = [];
            if isfield(obj.data,'dosePulling') && ...
                    isfield(obj.data.dosePulling,'nominal') && ...
                    isfield(obj.data.dosePulling.nominal,'initialWeights')
                nominalInitialWeights = obj.data.dosePulling.nominal.initialWeights;
            end

            resultGUINominal = obj.runFluenceOptimization( ...
                obj.data.dij,obj.data.cst,obj.data.pln,nominalInitialWeights);
            [resultGUINominal,dvhNominal,qiNominal] = obj.runPlanAnalysis( ...
                obj.data.ct,obj.data.cst,obj.data.stf,obj.data.pln, ...
                resultGUINominal,true);

            obj.data.resultGUINominal = resultGUINominal;
            obj.data.resultGUI = resultGUINominal;
            obj.data.dvhNominal = dvhNominal;
            obj.data.qiNominal = qiNominal;

            if ~isfield(obj.data,'robust')
                return;
            end

            obj.log(sprintf('Running robust optimization strategy %s.',obj.strategy.name));
            robustData = obj.data.robust;
            numPlans = numel(obj.runConfig.theta1);
            robustData.resultGUI = cell(1,numPlans);

            for planIx = 1:numPlans
                initialWeights = [];
                if isfield(robustData,'initialWeights') && ...
                        numel(robustData.initialWeights) >= planIx
                    initialWeights = robustData.initialWeights{planIx};
                elseif planIx > 1
                    initialWeights = robustData.resultGUI{planIx - 1}.w;
                end

                robustData.resultGUI{planIx} = obj.runFluenceOptimization( ...
                    robustData.dij,robustData.cst,robustData.pln,initialWeights);
            end

            obj.data.robust = robustData;
        end

        function doSampling(obj)
            obj.log('Sampling optimized workflow dose scenarios.');

            [ctSampling,cstSampling] = robOpt.io.loadGeometry( ...
                obj.runConfig,"sampling");
            cstSampling = robOpt.structures.normalizeNames( ...
                cstSampling,obj.runConfig);
            obj.validateSamplingStructures(cstSampling);
            cstSampling = obj.applySamplingStructureRoles(cstSampling);

            multScen = robOpt.scenario.createModel(ctSampling, ...
                obj.runConfig.sampling_scen_mode,obj.runConfig,'sampling');

            samplingData = struct();
            samplingData.ct = ctSampling;
            samplingData.cst = cstSampling;
            samplingData.multScen = multScen;
            samplingData.phaseProb = ones(1,ctSampling.numOfCtScen) / ctSampling.numOfCtScen;
            samplingData.scenarioMode = obj.runConfig.sampling_scen_mode;
            samplingData.wcSigma = obj.runConfig.sampling_wcSigma;
            samplingData.optimizationScenarioMode = obj.runConfig.scen_mode;
            samplingData.optimizationWcSigma = obj.runConfig.wcSigma;
            samplingData.scenarioBasis.optimization = obj.scenarioBasisMetadata( ...
                obj.runConfig.scen_mode,obj.runConfig.wcSigma);
            samplingData.scenarioBasis.sampling = obj.scenarioBasisMetadata( ...
                obj.runConfig.sampling_scen_mode,obj.runConfig.sampling_wcSigma);
            samplingData.nominal = obj.samplePlan(ctSampling,cstSampling, ...
                obj.data.stf,obj.data.pln,obj.data.resultGUINominal,multScen);

            if isfield(obj.data,'robust')
                robustData = obj.data.robust;
                samplingData.robust = cell(1,numel(robustData.resultGUI));
                for planIx = 1:numel(robustData.resultGUI)
                    obj.log(sprintf('Sampling robust plan %d of %d.', ...
                        planIx,numel(robustData.resultGUI)));
                    samplingData.robust{planIx} = obj.samplePlan( ...
                        ctSampling,cstSampling,robustData.stf,robustData.pln, ...
                        robustData.resultGUI{planIx},multScen);
                end
            end

            obj.data.sampling = samplingData;
        end

        function doAnalyze(obj)
            obj.log('Analyzing robust workflow results.');
            obj.runConfig.analysis = obj.completeAnalysisConfig(obj.runConfig.analysis);
            results = struct();
            results.runConfig = obj.runConfig;
            results.strategy = obj.strategy.name;
            results.nominal.qi = obj.data.qiNominal;
            results.nominal.dvh = obj.data.dvhNominal;

            if isfield(obj.data,'robust')
                robustData = obj.data.robust;
                results.robust = cell(1,numel(robustData.resultGUI));
                for planIx = 1:numel(robustData.resultGUI)
                    [robustData.resultGUI{planIx},dvhRobust,qiRobust] = ...
                        obj.runPlanAnalysis(robustData.ct,robustData.cst, ...
                        robustData.stf,robustData.pln, ...
                        robustData.resultGUI{planIx},true);
                    results.robust{planIx}.dvh = dvhRobust;
                    results.robust{planIx}.qi = qiRobust;
                end
                obj.data.robust = robustData;
            end

            results.analysis = obj.runConfig.analysis;
            if isfield(obj.data,'sampling')
                results.sampling = obj.analyzeSamplingData(obj.data.sampling);
            end

            obj.data.results = results;
            obj.logAnalysisResults(results);
        end
    end

    methods (Access = private)
        function config = charFields(obj,config,fieldNames) %#ok<INUSD>
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                if isfield(config,fieldName)
                    config.(fieldName) = char(config.(fieldName));
                end
            end
        end

        function output = mapStageFields(obj,input,fieldMap) %#ok<INUSD>
            output = struct();
            for i = 1:size(fieldMap,1)
                sourceField = fieldMap{i,1};
                targetField = fieldMap{i,2};
                if isfield(input,sourceField)
                    output.(targetField) = input.(sourceField);
                end
            end
        end

        function stageConfig = normalizeSamplingStageConfig(obj,stageConfig)
            obj.assertSameSamplingAlias(stageConfig,'scen_mode','sampling_scen_mode');
            obj.assertSameSamplingAlias(stageConfig,'wcSigma','sampling_wcSigma');
            obj.assertSameSamplingAlias(stageConfig,'size','sampling_size');
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
                error('robOpt:Engine:ConflictingSamplingConfig', ...
                    ['Sampling config fields "%s" and "%s" refer to the same ' ...
                     'setting but contain different values.'], ...
                    aliasField,explicitField);
            end
        end

        function basis = scenarioBasisMetadata(obj,scenarioMode,wcSigma)
            basis = struct();
            basis.scenarioMode = char(scenarioMode);
            basis.wcSigma = wcSigma;
            basis.shiftSD = obj.runConfig.shiftSD;
            basis.rangeAbsSD = obj.runConfig.rangeAbsSD;
            basis.rangeRelSD = obj.runConfig.rangeRelSD;
            basis.numOfRangeGridPoints = obj.runConfig.numOfRangeGridPoints;
        end

        function resultGUI = runFluenceOptimization(obj,dij,cst,pln,initialWeights)
            pln.propOpt.optimizer = obj.runConfig.optimizer;
            if nargin >= 5 && ~isempty(initialWeights)
                resultGUI = matRad_fluenceOptimization(dij,cst,pln,initialWeights);
            else
                resultGUI = matRad_fluenceOptimization(dij,cst,pln);
            end
        end

        function [resultGUI,dvh,qi] = runPlanAnalysis(obj,ct,cst,stf,pln,resultGUI,showFigures)
            [resultGUI,dvh,qi] = robOpt.analysis.PlanAnalysis.run( ...
                obj.runConfig.analysis,ct,cst,stf,pln,resultGUI,showFigures);
        end

        function [cst,report] = runNominalDosePulling(obj,ct,cst,dij,stf,pln)
            maxIterations = obj.runConfig.dose_pulling_max_iter;
            criteria = obj.expandCellToCount(obj.runConfig.dose_pulling1_criteria, ...
                numel(obj.runConfig.dose_pulling1_target),'dose_pulling1_criteria');
            limits = obj.expandNumericToCount(obj.runConfig.dose_pulling1_limit, ...
                numel(obj.runConfig.dose_pulling1_target),'dose_pulling1_limit');
            targetNames = obj.asCellstr(obj.runConfig.dose_pulling1_target);

            resultGUI = obj.runFluenceOptimization(dij,cst,pln,[]);
            [resultGUI,dvh,qi] = obj.runPlanAnalysis(ct,cst,stf,pln, ...
                resultGUI,false);
            targetIx = obj.findQiTargets(qi,obj.runConfig.dose_pulling1_target);
            history = obj.nominalDosePullingHistory(qi,targetIx,criteria, ...
                0,targetNames,limits);
            obj.logNominalDosePullingProgress(history(end),'initial');

            iteration = obj.runConfig.dose_pulling1_start + 1;
            while iteration <= maxIterations && ...
                    obj.nominalDosePullingNeedsUpdate(qi,targetIx,criteria,limits)
                [cst,optimizationFlag] = matRad_pullDose(cst,1);
                if ~optimizationFlag
                    obj.log(sprintf(['Dose pulling step 1 stopped at iteration %d ' ...
                        'because matRad_pullDose did not update any objective.'], ...
                        iteration));
                    break;
                end

                resultGUI = obj.runFluenceOptimization(dij,cst,pln,resultGUI.w);
                [resultGUI,dvh,qi] = obj.runPlanAnalysis(ct,cst,stf,pln, ...
                    resultGUI,false);
                history(end + 1) = obj.nominalDosePullingHistory( ...
                    qi,targetIx,criteria,iteration,targetNames,limits); %#ok<AGROW>
                obj.logNominalDosePullingProgress(history(end),'after pull');
                iteration = iteration + 1;
            end

            converged = ~obj.nominalDosePullingNeedsUpdate(qi,targetIx,criteria,limits);
            obj.logDosePullingSummary(1,converged,numel(history) - 1);

            report = struct();
            report.initialWeights = resultGUI.w;
            report.dvh = dvh;
            report.qi = qi;
            report.history = history;
            report.converged = converged;
            report.iterations = numel(history) - 1;
        end

        function robustData = refreshRobustDataAfterNominalPulling(obj,robustData)
            refreshedData = obj.prepareRobustData();
            [refreshedData.cst,refreshedData.pln] = obj.strategy.apply( ...
                refreshedData.cst,refreshedData.pln, ...
                refreshedData.objectiveInfo,obj.runConfig);

            robustData.cst = refreshedData.cst;
            robustData.pln = refreshedData.pln;
            robustData.stf = refreshedData.stf;
            robustData.phaseProb = refreshedData.phaseProb;
            robustData.objectiveInfo = refreshedData.objectiveInfo;
        end

        function [robustData,report] = runRobustDosePulling(obj,robustData)
            maxIterations = obj.runConfig.dose_pulling_max_iter;
            numPlans = numel(obj.runConfig.theta1);
            robustData.initialWeights = cell(1,numPlans);

            report = struct();
            report.plans = cell(1,numPlans);

            cst = robustData.cst;
            previousWeights = [];
            for planIx = 1:numPlans
                resultGUI = obj.runFluenceOptimization( ...
                    robustData.dij,cst,robustData.pln,previousWeights);
                metrics = obj.robustDosePullingMetrics(cst,robustData.pln, ...
                    resultGUI,robustData.phaseProb);
                metrics.planIndex = planIx;
                history = metrics;
                obj.logRobustDosePullingProgress(metrics,planIx,numPlans,'initial');

                iteration = obj.runConfig.dose_pulling2_start + 1;
                while iteration <= maxIterations && ...
                        obj.robustDosePullingNeedsUpdate(metrics)
                    [cst,optimizationFlag] = matRad_pullDose(cst,2);
                    if ~optimizationFlag
                        obj.log(sprintf(['Dose pulling step 2 plan %d/%d stopped ' ...
                            'at iteration %d because matRad_pullDose did not ' ...
                            'update any objective.'],planIx,numPlans,iteration));
                        break;
                    end

                    resultGUI = obj.runFluenceOptimization( ...
                        robustData.dij,cst,robustData.pln,resultGUI.w);
                    metrics = obj.robustDosePullingMetrics(cst,robustData.pln, ...
                        resultGUI,robustData.phaseProb,iteration);
                    metrics.planIndex = planIx;
                    history(end + 1) = metrics; %#ok<AGROW>
                    obj.logRobustDosePullingProgress(metrics,planIx,numPlans,'after pull');
                    iteration = iteration + 1;
                end

                converged = ~obj.robustDosePullingNeedsUpdate(metrics);
                obj.logDosePullingSummary(2,converged,numel(history) - 1, ...
                    planIx,numPlans);

                robustData.initialWeights{planIx} = resultGUI.w;
                previousWeights = resultGUI.w;
                report.plans{planIx} = struct( ...
                    'history',history, ...
                    'converged',converged, ...
                    'iterations',numel(history) - 1);
            end

            robustData.cst = cst;
        end

        function history = nominalDosePullingHistory(obj,qi,targetIx,criteria,iteration,targetNames,limits) %#ok<INUSD>
            if nargin < 5
                iteration = 0;
            end
            if nargin < 6 || isempty(targetNames)
                targetNames = arrayfun(@(ix) qi(ix).name,targetIx,'UniformOutput',false);
            end
            if nargin < 7 || isempty(limits)
                limits = NaN(1,numel(targetIx));
            end

            values = zeros(1,numel(targetIx));
            for i = 1:numel(targetIx)
                values(i) = qi(targetIx(i)).(criteria{i});
            end

            history = struct();
            history.step = 1;
            history.iteration = iteration;
            history.targetNames = targetNames;
            history.criteria = criteria;
            history.limits = limits;
            history.values = values;
            history.isSatisfied = all(values >= limits);
        end

        function tf = nominalDosePullingNeedsUpdate(obj,qi,targetIx,criteria,limits) %#ok<INUSD>
            values = zeros(1,numel(targetIx));
            for i = 1:numel(targetIx)
                values(i) = qi(targetIx(i)).(criteria{i});
            end

            tf = any(values < limits);
        end

        function metrics = robustDosePullingMetrics(obj,cst,pln,resultGUI,phaseProb,iteration)
            if nargin < 6
                iteration = 0;
            end

            criteria = obj.expandCellToCount(obj.runConfig.dose_pulling1_criteria, ...
                numel(obj.runConfig.dose_pulling1_target),'dose_pulling1_criteria');
            scenProb = matRad_getScenProb(pln,phaseProb);
            scenarioValues = zeros(pln.multScen.totNumScen,numel(criteria));

            for scenIt = 1:pln.multScen.totNumScen
                doseField = [pln.bioParam.quantityVis '_' num2str(scenIt)];
                doseScale = obj.analysisDoseScale(pln);
                qi = matRad_calcQualityIndicators(cst,pln, ...
                    resultGUI.(doseField) * doseScale,[],[], ...
                    'doseScale',doseScale);
                targetIx = obj.findQiTargets(qi,obj.runConfig.dose_pulling1_target);
                for targetIt = 1:numel(criteria)
                    scenarioValues(scenIt,targetIt) = ...
                        qi(targetIx(targetIt)).(criteria{targetIt});
                end
            end

            metrics = struct();
            metrics.step = 2;
            metrics.iteration = iteration;
            metrics.targetNames = obj.asCellstr(obj.runConfig.dose_pulling1_target);
            metrics.criteria = criteria;
            metrics.meanQiTarget = sum(scenarioValues .* scenProb(:),1);
            metrics.minQiTarget = min(scenarioValues,[],1);
            metrics.selectedCriterion = obj.runConfig.dose_pulling2_criteria;
            metrics.selectedValues = obj.selectRobustDosePullingCriteria(metrics);
            metrics.limits = obj.expandNumericToCount(obj.runConfig.dose_pulling2_limit, ...
                numel(metrics.selectedValues),'dose_pulling2_limit');
            metrics.isSatisfied = all(metrics.selectedValues >= metrics.limits);
        end

        function tf = robustDosePullingNeedsUpdate(obj,metrics)
            if isfield(metrics,'selectedValues') && isfield(metrics,'limits')
                criteriaValues = metrics.selectedValues;
                limits = metrics.limits;
            else
                criteriaValues = obj.selectRobustDosePullingCriteria(metrics);
                limits = obj.expandNumericToCount(obj.runConfig.dose_pulling2_limit, ...
                    numel(criteriaValues),'dose_pulling2_limit');
            end
            tf = any(criteriaValues < limits);
        end

        function logNominalDosePullingProgress(obj,entry,label)
            if entry.iteration == 0
                iterationText = 'initial criteria';
            else
                iterationText = sprintf('%s, iteration %d',label,entry.iteration);
            end

            obj.log(sprintf('Dose pulling step 1 %s: %s.', ...
                iterationText,obj.formatDosePullingCriteria( ...
                entry.targetNames,entry.criteria,entry.values,entry.limits)));
        end

        function logRobustDosePullingProgress(obj,metrics,planIx,numPlans,label)
            if metrics.iteration == 0
                iterationText = 'initial criteria';
            else
                iterationText = sprintf('%s, iteration %d',label,metrics.iteration);
            end

            obj.log(sprintf('Dose pulling step 2 plan %d/%d %s: %s.', ...
                planIx,numPlans,iterationText, ...
                obj.formatRobustDosePullingCriteria(metrics)));
        end

        function logDosePullingSummary(obj,step,converged,numPulls,planIx,numPlans)
            if converged
                statusText = 'converged';
            else
                statusText = 'stopped without convergence';
            end

            if nargin < 5
                obj.log(sprintf('Dose pulling step %d %s after %d pulls.', ...
                    step,statusText,numPulls));
            else
                obj.log(sprintf(['Dose pulling step %d plan %d/%d %s after ' ...
                    '%d pulls.'],step,planIx,numPlans,statusText,numPulls));
            end
        end

        function logNominalDosePullingResults(obj,report)
            if ~isfield(report,'history') || isempty(report.history)
                obj.log('Dose pulling step 1 results: no history available.');
                return;
            end

            finalEntry = report.history(end);
            obj.log(sprintf('Dose pulling step 1 results: converged=%s, pulls=%d, final %s.', ...
                obj.logicalText(report.converged),report.iterations, ...
                obj.formatDosePullingCriteria(finalEntry.targetNames, ...
                finalEntry.criteria,finalEntry.values,finalEntry.limits)));
        end

        function logRobustDosePullingResults(obj,report)
            if ~isfield(report,'plans') || isempty(report.plans)
                obj.log('Dose pulling step 2 results: no robust plans available.');
                return;
            end

            for planIx = 1:numel(report.plans)
                planReport = report.plans{planIx};
                if ~isfield(planReport,'history') || isempty(planReport.history)
                    obj.log(sprintf('Dose pulling step 2 plan %d results: no history available.', ...
                        planIx));
                    continue;
                end

                finalMetrics = planReport.history(end);
                obj.log(sprintf(['Dose pulling step 2 plan %d results: converged=%s, ' ...
                    'pulls=%d, final %s.'],planIx, ...
                    obj.logicalText(planReport.converged),planReport.iterations, ...
                    obj.formatRobustDosePullingCriteria(finalMetrics)));
            end
        end

        function text = formatDosePullingCriteria(obj,targetNames,criteria,values,limits) %#ok<INUSD>
            parts = cell(1,numel(values));
            for i = 1:numel(values)
                if values(i) >= limits(i)
                    statusText = 'ok';
                else
                    statusText = 'below limit';
                end

                parts{i} = sprintf('%s(%s)=%.6g, limit=%.6g, gap=%+.6g [%s]', ...
                    criteria{i},targetNames{i},values(i),limits(i), ...
                    values(i) - limits(i),statusText);
            end

            text = strjoin(parts,'; ');
        end

        function text = formatRobustDosePullingCriteria(obj,metrics) %#ok<INUSD>
            parts = cell(1,numel(metrics.selectedValues));
            for i = 1:numel(metrics.selectedValues)
                if metrics.selectedValues(i) >= metrics.limits(i)
                    statusText = 'ok';
                else
                    statusText = 'below limit';
                end

                if strcmp(metrics.selectedCriterion,'meanQiTarget')
                    companionText = sprintf('minQiTarget=%.6g', ...
                        metrics.minQiTarget(i));
                else
                    companionText = sprintf('meanQiTarget=%.6g', ...
                        metrics.meanQiTarget(i));
                end

                parts{i} = sprintf(['%s(%s/%s)=%.6g, %s, limit=%.6g, ' ...
                    'gap=%+.6g [%s]'],metrics.selectedCriterion, ...
                    metrics.targetNames{i},metrics.criteria{i}, ...
                    metrics.selectedValues(i),companionText,metrics.limits(i), ...
                    metrics.selectedValues(i) - metrics.limits(i),statusText);
            end

            text = strjoin(parts,'; ');
        end

        function text = logicalText(obj,value) %#ok<INUSD>
            if value
                text = 'true';
            else
                text = 'false';
            end
        end

        function logAnalysisResults(obj,results)
            robOpt.analysis.ResultLogger.log(@(message) obj.log(message),results);
        end

        function expectedQi = expectedQiFromCstStat(~,cstStat,cst,pln,doseMode)
            expectedQi = robOpt.analysis.ExpectedQi.fromCstStat( ...
                cstStat,cst,pln,doseMode);
        end

        function values = selectRobustDosePullingCriteria(obj,metrics)
            switch obj.runConfig.dose_pulling2_criteria
                case 'meanQiTarget'
                    values = metrics.meanQiTarget;
                case 'minQiTarget'
                    values = metrics.minQiTarget;
                otherwise
                    error('robOpt:Engine:UnknownDosePullingCriteria', ...
                        'Unknown dose_pulling2_criteria "%s".', ...
                        obj.runConfig.dose_pulling2_criteria);
            end
        end

        function targetIx = findQiTargets(obj,qi,targetNames)
            targetNames = obj.asCellstr(targetNames);
            targetIx = zeros(1,numel(targetNames));

            for targetIt = 1:numel(targetNames)
                for qiIt = 1:numel(qi)
                    if strcmp(qi(qiIt).name,targetNames{targetIt})
                        targetIx(targetIt) = qiIt;
                        break;
                    end
                end

                if targetIx(targetIt) == 0
                    error('robOpt:Engine:MissingDosePullingTarget', ...
                        'Dose pulling target "%s" was not found in quality indicators.', ...
                        targetNames{targetIt});
                end
            end
        end

        function values = expandNumericToCount(obj,values,count,fieldName) %#ok<INUSD>
            values = values(:)';
            if isscalar(values)
                values = repmat(values,1,count);
            end
            if numel(values) ~= count
                error('robOpt:Engine:InvalidConfigLength', ...
                    '%s must be scalar or contain %d values.',fieldName,count);
            end
        end

        function values = expandCellToCount(obj,values,count,fieldName)
            values = obj.asCellstr(values);
            if isscalar(values) && count > 1
                values = repmat(values,1,count);
            end
            if numel(values) ~= count
                error('robOpt:Engine:InvalidConfigLength', ...
                    '%s must be scalar or contain %d values.',fieldName,count);
            end
        end

        function sample = samplePlan(obj,ctSampling,cstSampling,stf,pln,resultGUI,multScen)
            if ~isfield(resultGUI,'w')
                error('robOpt:Engine:MissingWeights', ...
                    'Cannot sample a plan before optimized fluence weights are available.');
            end

            structSel = {};
            [caSamp,mSampDose,plnSamp,resultGUINomScen] = matRad_sampling( ...
                ctSampling,stf,cstSampling,pln,resultGUI.w,structSel,multScen, ...
                'doseMode',obj.runConfig.analysis.doseMode, ...
                'dvhDoseWindow',obj.runConfig.analysis.doseWindowDvh);

            sample = struct();
            sample.caSamp = caSamp;
            sample.mSampDose = mSampDose;
            sample.pln = plnSamp;
            sample.resultGUINomScen = resultGUINomScen;
        end

        function samplingResults = analyzeSamplingData(obj,samplingData)
            obj.log('Analyzing sampled dose scenarios.');

            samplingResults = struct();
            samplingResults.scenarioMode = samplingData.scenarioMode;
            samplingResults.nominal = obj.analyzeSamplingPlan( ...
                samplingData,samplingData.nominal,'nominal');

            if isfield(samplingData,'robust')
                samplingResults.robust = cell(1,numel(samplingData.robust));
                for planIx = 1:numel(samplingData.robust)
                    label = sprintf('robust_%d',planIx);
                    samplingResults.robust{planIx} = obj.analyzeSamplingPlan( ...
                        samplingData,samplingData.robust{planIx},label);
                end
            end
        end

        function planSamplingResults = analyzeSamplingPlan(obj,samplingData,sample,label)
            analysis = obj.runConfig.analysis;
            slice = obj.samplingSlice(samplingData.ct,sample.pln);

            [cstStat,doseStat,meta,gammaFig,robustnessFig1,robustnessFig2] = ...
                matRad_samplingAnalysis(samplingData.ct,samplingData.cst, ...
                sample.pln,sample.caSamp,sample.mSampDose, ...
                sample.resultGUINomScen, ...
                'phaseProb',samplingData.phaseProb, ...
                'gammaCriterion',analysis.gammaCriteria, ...
                'robustnessCriteria',analysis.robustnessCriteria, ...
                'doseMode',analysis.doseMode, ...
                'slice',slice);

            planSamplingResults = struct();
            planSamplingResults.cstStat = cstStat;
            planSamplingResults.doseStat = doseStat;
            planSamplingResults.meta = meta;
            planSamplingResults.expectedQi = obj.expectedQiFromCstStat( ...
                cstStat,samplingData.cst,sample.pln,analysis.doseMode);
            planSamplingResults.expectedQiSource = ...
                'cstStat(i).dvhStat.mean from matRad_samplingAnalysis';
            planSamplingResults.expectedDvhSource = ...
                'cstStat(i).dvhStat.mean from matRad_samplingAnalysis';
            planSamplingResults.figureFiles = obj.saveSamplingAnalysisFigures( ...
                label,gammaFig,robustnessFig1,robustnessFig2, ...
                samplingData,sample,doseStat,analysis,slice);
        end

        function figureFiles = saveSamplingAnalysisFigures(obj,label,gammaFig,robustnessFig1,robustnessFig2,samplingData,sample,doseStat,analysis,slice)
            analysisFolder = fullfile(obj.rootPath,'sampling_analysis');
            figureFiles = robOpt.analysis.Figures.saveSamplingAnalysisFigures( ...
                analysisFolder,label,gammaFig,robustnessFig1, ...
                robustnessFig2,samplingData,sample,doseStat,analysis,slice);
        end

        function slice = samplingSlice(obj,ct,pln) %#ok<INUSD>
            isocenter = pln.propStf.isoCenter(1,:);
            if isfield(ct,'z') && ~isempty(ct.z)
                [~,slice] = min(abs(ct.z - isocenter(3)));
            else
                slice = round(isocenter(3) / ct.resolution.z);
            end

            slice = max(1,min(ct.cubeDim(3),slice));
        end

        function validateSamplingStructures(obj,cstSampling)
            if isfield(obj.data,'robust')
                referenceCst = obj.data.robust.cst;
            else
                referenceCst = obj.data.cst;
            end

            ringIx = [obj.data.objectiveInfo.ixRing1 obj.data.objectiveInfo.ixRing2];
            for itStructure = 1:size(referenceCst,1)
                if any(itStructure == ringIx)
                    continue;
                end
                if itStructure > size(cstSampling,1) || ...
                        ~strcmp(referenceCst{itStructure,2},cstSampling{itStructure,2})
                    error('robOpt:Engine:SamplingStructureMismatch', ...
                        ['Optimization and sampling cases must have matching ' ...
                         'structures before sampling.']);
                end
            end
        end

        function cstSampling = applySamplingStructureRoles(obj,cstSampling)
            if strcmp(obj.runConfig.plan_target,'PTV')
                ixTarget = obj.data.objectiveInfo.ixTarget;
                if ixTarget <= size(cstSampling,1)
                    cstSampling{ixTarget,3} = 'OAR';
                end
            end
        end

        function [ct,cst] = ensureDeformationFields(obj,ct,cst) %#ok<INUSD>
            if ct.numOfCtScen > 1
                metadata.nItera = 100;
                metadata.dvfType = 'push';
                register = matRad_ElasticImageRegistration(ct,cst,1,metadata);
                if ct.numOfCtScen > numel(cst{1,4})
                    [ct,cst] = register.propContours();
                end
                metadata.dvfType = 'pull';
                register = matRad_ElasticImageRegistration(ct,cst,1,metadata);
                ct = register.calcDVF();
            end
        end

        function [cst,objectiveInfo] = prepareNominalObjectives(obj,ct,cst)
            runConfigTmp = obj.runConfig;
            runConfigTmp.plan_objectives = '4';
            dpStart = [runConfigTmp.dose_pulling1_start 0];
            nominalTarget = string(runConfigTmp.dose_pulling1_target{end});
            [cst,ixTarget,p,ixBody,ixCTV,oarStructSel] = ...
                robOpt.plan.loadObjectives( ...
                runConfigTmp,nominalTarget,dpStart,cst);

            cst{ixTarget,5}.Visible = true;
            [cst,ixRing1,ixRing2] = obj.addDefaultRings(cst,ct,ixTarget,ixBody);
            cst = obj.applyDefaultRingObjectives(cst,ixRing1,ixRing2,p);
            objectiveInfo = struct();
            objectiveInfo.ixTarget = ixTarget;
            objectiveInfo.ixBody = ixBody;
            objectiveInfo.ixCTV = ixCTV;
            objectiveInfo.ixRing1 = ixRing1;
            objectiveInfo.ixRing2 = ixRing2;
            objectiveInfo.oarStructSel = oarStructSel;
            objectiveInfo.prescriptionDose = p;
        end

        function [cst,ixRing1,ixRing2] = addDefaultRings(obj,cst,ct,ixTarget,ixBody) %#ok<INUSD>
            [cst,ixRing1,ixRing2] = robOpt.plan.Objectives.addDefaultRings( ...
                cst,ct,ixTarget,ixBody);
        end

        function cst = applyDefaultRingObjectives(obj,cst,ixRing1,ixRing2,p) %#ok<INUSD>
            cst = robOpt.plan.Objectives.applyDefaultRingObjectives( ...
                cst,ixRing1,ixRing2,p);
        end

        function setDoseWindows(obj,p,pln)
            analysis = obj.normalizeAnalysisConfig(obj.runConfig.analysis);
            analysis = robOpt.config.Analysis.applyPrescriptionDefaults( ...
                analysis,p,pln);
            obj.runConfig.analysis = analysis;
        end

        function analysis = defaultAnalysisConfig(obj) %#ok<MANU>
            analysis = robOpt.config.Analysis.defaults();
        end

        function analysis = normalizeAnalysisConfig(obj,analysis) %#ok<INUSD>
            analysis = robOpt.config.Analysis.normalize(analysis);
        end

        function analysis = completeAnalysisConfig(obj,analysis)
            analysis = obj.normalizeAnalysisConfig(analysis);
            if obj.hasPrescriptionAnalysisContext()
                analysis = robOpt.config.Analysis.applyPrescriptionDefaults( ...
                    analysis,obj.data.objectiveInfo.prescriptionDose,obj.data.pln);
            end
        end

        function tf = hasPrescriptionAnalysisContext(obj)
            tf = isfield(obj.data,'pln') && isfield(obj.data,'objectiveInfo') && ...
                isstruct(obj.data.objectiveInfo) && ...
                isfield(obj.data.objectiveInfo,'prescriptionDose') && ...
                ~isempty(obj.data.objectiveInfo.prescriptionDose);
        end

        function doseScale = analysisDoseScale(obj,pln)
            doseScale = robOpt.analysis.PlanAnalysis.doseScale( ...
                pln,obj.runConfig.analysis.doseMode);
        end

        function [pln,quantityOpt] = createPlan(obj,ct,cst)
            [pln,quantityOpt] = robOpt.plan.Plan.create( ...
                obj.runConfig,ct,cst);
        end

        function robustData = prepareRobustData(obj)
            cstRobust = obj.data.cst;
            dpStart = [obj.runConfig.dose_pulling1_start obj.runConfig.dose_pulling2_start];
            [cstRobust,ixTarget,p,ixBody,ixCTV,oarStructSel] = ...
                robOpt.plan.loadObjectives( ...
                obj.runConfig,string(obj.runConfig.plan_target),dpStart,cstRobust);

            for itOARStructure = 1:numel(oarStructSel)
                for itStructure = 1:size(cstRobust,1)
                    if strcmp(obj.data.cst{itStructure,2},oarStructSel{itOARStructure})
                        cstRobust{itStructure,6} = obj.data.cst{itStructure,6};
                    end
                end
            end

            cstRobust = robOpt.structures.scaleDoseObjectives( ...
                cstRobust,oarStructSel,obj.runConfig.scale_factor);
            cstRobust = obj.applyDefaultRingObjectives(cstRobust, ...
                obj.data.objectiveInfo.ixRing1,obj.data.objectiveInfo.ixRing2,p);

            plnRobust = obj.data.pln;
            multScen = robOpt.scenario.createModel(obj.data.ct, ...
                obj.runConfig.scen_mode,obj.runConfig,'optimization');
            plnRobust.multScen = multScen;
            stfRobust = matRad_generateStf(obj.data.ct,cstRobust,plnRobust);

            robustData = struct();
            robustData.ct = obj.data.ct;
            robustData.cst = cstRobust;
            robustData.pln = plnRobust;
            robustData.stf = stfRobust;
            robustData.phaseProb = multScen.ctScenProb(:,2)';
            robustData.objectiveInfo = struct('ixTarget',ixTarget,'ixBody',ixBody, ...
                'ixCTV',ixCTV,'oarStructSel',{oarStructSel},'prescriptionDose',p);
        end
    end
end
