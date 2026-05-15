classdef SamplingService
    % SamplingService Owns dose-scenario sampling execution.

    methods (Static)
        function [ctSampling,cstSampling,normalizationReport] = ...
                samplingGeometry(context)
            normalizationReport = struct();
            runConfig = context.runConfig;
            if runConfig.sampling_linkToOptimization
                context.reportGuiStageProgress('sample',0.02, ...
                    'Using optimization geometry for sampling.');
                optimizationInput = ...
                    planWorkflow.precompute.OptimizationInput.requireLight( ...
                    context.data,'linked sampling geometry');
                ctSampling = optimizationInput.ct;
                cstSampling = optimizationInput.cst;
                context.reportGuiStageProgress('sample',0.18, ...
                    'Using optimization structures for sampling.');
                return;
            end

            context.reportGuiStageProgress('sample',0.02, ...
                'Loading sampling geometry.');
            [ctSampling,cstSampling] = planWorkflow.io.loadGeometry( ...
                runConfig,"sampling");
            context.reportGuiStageProgress('sample',0.18, ...
                'Normalizing sampling structures.');
            [cstSampling,normalizationReport] = ...
                planWorkflow.structures.normalizeNames( ...
                cstSampling,runConfig,ctSampling);
            planWorkflow.structures.NormalizationReportLogger.log( ...
                context.log,'Sampling structure normalization', ...
                normalizationReport);
            [ctSampling,cstSampling] = ...
                planWorkflow.precompute.PrepareService.ensureDeformationFields( ...
                ctSampling,cstSampling);
            [cstSampling,~] = ...
                planWorkflow.precompute.PrepareService.prepareTemplateStructures( ...
                runConfig,context.planTemplate,ctSampling,cstSampling);
        end

        function cstSampling = prepareStructures(context,cstSampling)
            planWorkflow.sampling.SamplingService.validateStructures( ...
                context,cstSampling);
        end

        function validateStructures(context,cstSampling)
            samplingEntry = ...
                planWorkflow.sampling.SamplingService.samplingEntry( ...
                cstSampling);
            planWorkflow.sampling.SamplingEvaluationSpec.validateSamplingCst( ...
                cstSampling,samplingEntry);
            requirements = ...
                planWorkflow.sampling.SamplingService.structureRequirements( ...
                context);
            planWorkflow.sampling.SamplingEvaluationSpec.validateStructureRequirements( ...
                cstSampling,requirements,samplingEntry);
        end

        function requirements = structureRequirements(context)
            requirements = ...
                planWorkflow.sampling.SamplingService.emptyRequirement();
            if isstruct(context) && isfield(context,'runConfig') && ...
                    isstruct(context.runConfig) && ...
                    isfield(context.runConfig,'analysis') && ...
                    isstruct(context.runConfig.analysis)
                analysis = context.runConfig.analysis;
                requirements = ...
                    planWorkflow.sampling.SamplingService.addRobustnessTargets( ...
                    requirements,analysis);
            end
            requirements = ...
                planWorkflow.sampling.SamplingService.addEndpointStructures( ...
                requirements,context);
        end

        function requirements = addRobustnessTargets(requirements,analysis)
            if ~isfield(analysis,'robustnessTargetMode') || ...
                    strcmp(char(analysis.robustnessTargetMode),'all') || ...
                    ~isfield(analysis,'robustnessTargets') || ...
                    isempty(analysis.robustnessTargets)
                return;
            end
            targets = analysis.robustnessTargets;
            if ischar(targets) || isstring(targets)
                targets = cellstr(targets);
            end
            for targetIx = 1:numel(targets)
                requirements(end + 1) = ...
                    planWorkflow.sampling.SamplingService.requirement( ...
                    'analysis robustness target',{char(targets{targetIx})}); %#ok<AGROW>
            end
        end

        function requirements = addEndpointStructures(requirements,context)
            if ~isstruct(context) || ~isfield(context,'runConfig')
                return;
            end
            endpointQuantity = '';
            if isfield(context,'data') && isstruct(context.data) && ...
                    isfield(context.data,'quantityVis') && ...
                    ~isempty(context.data.quantityVis)
                endpointQuantity = char(context.data.quantityVis);
            else
                endpointQuantity = ...
                    planWorkflow.plan.DoseQuantityResolver.visualFromRunConfig( ...
                    context.runConfig);
            end
            endpointRequirements = ...
                planWorkflow.analysis.EndpointStructureContract.requirements( ...
                context.runConfig,endpointQuantity);
            for requirementIx = 1:numel(endpointRequirements)
                requirements(end + 1) = endpointRequirements(requirementIx); %#ok<AGROW>
            end
        end

        function requirements = emptyRequirement()
            requirements = repmat(struct('label','', ...
                'alternatives',{{}},'required',true,'source','', ...
                'metric','','kind',''),0,1);
        end

        function item = requirement(label,alternatives)
            item = planWorkflow.sampling.SamplingService.emptyRequirement();
            item(1).label = char(label);
            if ischar(alternatives) || isstring(alternatives)
                alternatives = cellstr(alternatives);
            end
            item(1).alternatives = ...
                cellfun(@char,alternatives,'UniformOutput',false);
            item(1).required = true;
            item(1).source = 'sampling';
            item(1).metric = '';
            item(1).kind = '';
        end

        function sample = samplePlanWithProgress(context,ctSampling, ...
                cstSampling,stf,pln,resultGUI,multScen, ...
                completedPlans,totalPlans,planLabel)
            progressState = ...
                planWorkflow.sampling.SamplingService.startMatRadProgress( ...
                context,completedPlans,totalPlans,planLabel);
            cleanupObj = onCleanup(@() ...
                planWorkflow.sampling.SamplingService.stopMatRadProgress( ...
                context,progressState)); %#ok<NASGU>
            sample = planWorkflow.sampling.SamplingService.samplePlan( ...
                context,ctSampling,cstSampling,stf,pln, ...
                resultGUI,multScen);
            planWorkflow.sampling.SamplingService.pollMatRadProgress( ...
                context,progressState);
        end

        function sample = samplePlan(context,ctSampling,cstSampling, ...
                stf,pln,resultGUI,multScen)
            if ~isfield(resultGUI,'w')
                error('planWorkflow:sampling:SamplingService:MissingWeights', ...
                    ['Cannot sample a plan before optimized fluence ' ...
                     'weights are available.']);
            end

            cstForSampling = cstSampling;
            dvhDoseWindow = matRad_convertFromEvaluationMode( ...
                context.runConfig.analysis.doseWindowDvh,pln, ...
                context.runConfig.analysis.evaluationMode);
            structSel = {};
            samplingOptions = ...
                planWorkflow.config.Resources.samplingNameValuePairs( ...
                context.runConfig);
            [caSamp,mSampDose,plnSamp,resultGUINomScen] = matRad_sampling( ...
                ctSampling,stf,cstForSampling,pln,resultGUI.w,structSel, ...
                multScen,'dvhDoseWindow',dvhDoseWindow,samplingOptions{:});

            sample = struct();
            sample.caSamp = caSamp;
            sample.mSampDose = mSampDose;
            sample.pln = plnSamp;
            sample.resultGUINomScen = resultGUINomScen;
        end

        function entry = samplingEntry(cstSampling)
            entry = struct();
            entry.role = 'sampling';
            entry.planId = 'sampling';
            entry.variantId = '';
            entry.planLabel = 'Sampling geometry';
            entry.label = 'Sampling geometry';
            entry.robustnessMode = '';
            entry.scenario = struct();
            entry.optimization4D = struct();
            entry.stf = [];
            entry.pln = [];
            entry.resultGUI = [];
        end

        function reportPlanProgress(context,completedPlans,totalPlans,message)
            context.reportGuiStageProgress('sample', ...
                planWorkflow.sampling.SamplingService.planStageFraction( ...
                completedPlans,totalPlans),message);
        end

        function fraction = planStageFraction(completedPlans,totalPlans)
            baseFraction = 0.45;
            planSpan = 0.50;
            totalPlans = max(1,totalPlans);
            planFraction = max(0,min(1,completedPlans / totalPlans));
            fraction = baseFraction + planSpan * planFraction;
        end

        function progressState = startMatRadProgress( ...
                context,completedPlans,totalPlans,planLabel)
            progressState = struct();
            progressState.enabled = isfield(context,'reportGuiStageProgress') && ...
                ~isempty(context.reportGuiStageProgress);
            progressState.timer = [];
            progressState.matRadCfg = [];
            progressState.restoreKeepLog = [];
            progressState.startLogCount = 0;
            progressState.completedPlans = completedPlans;
            progressState.totalPlans = max(1,totalPlans);
            progressState.planLabel = char(planLabel);

            if ~progressState.enabled
                return;
            end

            progressState.matRadCfg = MatRad_Config.instance();
            progressState.restoreKeepLog = progressState.matRadCfg.keepLog;
            progressState.matRadCfg.keepLog = true;
            progressState.startLogCount = size( ...
                progressState.matRadCfg.messageLog,1);
            try
                progressState.timer = timer( ...
                    'ExecutionMode','fixedSpacing', ...
                    'Period',0.5, ...
                    'BusyMode','drop', ...
                    'TimerFcn',@(~,~) ...
                    planWorkflow.sampling.SamplingService.pollMatRadProgress( ...
                    context,progressState));
                start(progressState.timer);
            catch
                progressState.matRadCfg.keepLog = ...
                    progressState.restoreKeepLog;
                progressState.enabled = false;
                progressState.timer = [];
            end
        end

        function stopMatRadProgress(context,progressState)
            if ~isstruct(progressState) || ~progressState.enabled
                return;
            end

            planWorkflow.sampling.SamplingService.pollMatRadProgress( ...
                context,progressState);
            if ~isempty(progressState.timer) && isvalid(progressState.timer)
                stop(progressState.timer);
                delete(progressState.timer);
            end
            if ~isempty(progressState.matRadCfg)
                progressState.matRadCfg.keepLog = ...
                    progressState.restoreKeepLog;
            end
        end

        function pollMatRadProgress(context,progressState)
            try
                if ~isstruct(progressState) || ~progressState.enabled || ...
                        isempty(progressState.matRadCfg)
                    return;
                end

                messageLog = progressState.matRadCfg.messageLog;
                if size(messageLog,1) <= progressState.startLogCount
                    return;
                end

                messages = messageLog(progressState.startLogCount + 1:end,2);
                [finishedScenarios,totalScenarios] = ...
                    planWorkflow.sampling.SamplingService.latestProgress( ...
                    messages);
                if isempty(finishedScenarios) || totalScenarios <= 0
                    return;
                end

                stageFraction = ...
                    planWorkflow.sampling.SamplingService.planStageFraction( ...
                    progressState.completedPlans + ...
                    finishedScenarios / totalScenarios, ...
                    progressState.totalPlans);
                context.reportGuiStageProgress('sample',stageFraction, ...
                    sprintf('%s: %d/%d scenarios.', ...
                    progressState.planLabel,finishedScenarios, ...
                    totalScenarios));
            catch
            end
        end

        function [finishedScenarios,totalScenarios] = latestProgress(messages)
            finishedScenarios = [];
            totalScenarios = [];
            for i = 1:numel(messages)
                tokens = regexp(messages{i}, ...
                    ['Sampling progress:\s*(\d+)\s*scenarios ' ...
                     'of\s*(\d+)'], ...
                    'tokens','once');
                if ~isempty(tokens)
                    finishedScenarios = str2double(tokens{1});
                    totalScenarios = str2double(tokens{2});
                end
            end
        end
    end
end
