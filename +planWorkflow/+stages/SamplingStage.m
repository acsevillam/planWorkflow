classdef SamplingStage
    % SamplingStage Samples optimized plans over dose scenarios.

    methods (Static)
        function context = workflowContext(varargin)
            if nargin == 3 && ...
                    planWorkflow.stages.WorkflowRuntime.isRuntime(varargin{3})
                runConfig = varargin{1};
                data = varargin{2};
                runtime = varargin{3};
                taskRunner = runtime.taskRunner();
                logFn = runtime.logFn();
                planTemplate = ...
                    planWorkflow.stages.ContextValidator.planTemplate( ...
                    runConfig,data);
                reportGuiStageProgress = ...
                    runtime.reportGuiStageProgressFn();
            else
                [runConfig,data,taskRunner,logFn,planTemplate, ...
                    reportGuiStageProgress] = varargin{:};
            end
            context = planWorkflow.stages.SamplingStage.context( ...
                runConfig,data,taskRunner,logFn,planTemplate, ...
                reportGuiStageProgress);
        end

        function context = context(runConfig,data,taskRunner,logFn, ...
                planTemplate,reportGuiStageProgress)
            data = planWorkflow.stages.ContextValidator.dataSlice( ...
                data,{'ct','cst','stf','pln','optimizationInput', ...
                'resultGUIReference'}, ...
                {'robustPlans','objectiveInfo','quantityOpt','quantityVis', ...
                'planTemplate'}, ...
                'sample');
            context = planWorkflow.stages.ContextValidator.base( ...
                'sample',runConfig,data,taskRunner,logFn);
            context.planTemplate = planTemplate;
            context.reportGuiStageProgress = reportGuiStageProgress;
            planWorkflow.stages.ContextValidator.requireFields( ...
                context,{'planTemplate','reportGuiStageProgress'}, ...
                'sample');
        end

        function patch = run(context)
            data = context.data;
            runConfig = context.runConfig;
            logFn = context.log;

            logFn('Sampling optimized workflow dose scenarios.');
            analysis = planWorkflow.analysis.AnalysisService.completeConfig( ...
                runConfig,data);
            context.runConfig.analysis = analysis;
            planSet = planWorkflow.sampling.SamplingPlanSet.fromData( ...
                runConfig,data);
            sampledPlanCount = numel(planSet.entries);

            [ctSampling,cstSampling,samplingNormalizationReport] = ...
                planWorkflow.sampling.SamplingService.samplingGeometry( ...
                context);
            cstSampling = ...
                planWorkflow.sampling.SamplingService.prepareStructures( ...
                context,cstSampling);
            context.reportGuiStageProgress('sample',0.34, ...
                'Building scenario model.');

            samplingScenarioConfig = planWorkflow.config.ScenarioSpec.fromRunConfig( ...
                runConfig,'sampling');
            samplingScenarioConfig = planWorkflow.config.ScenarioSpec.matRadScenario( ...
                samplingScenarioConfig);
            samplingScenarioConfig = ...
                planWorkflow.sampling.SamplingPlanSet.withPlanSetBeamCount( ...
                samplingScenarioConfig,planSet);
            multScen = planWorkflow.scenario.createModel(ctSampling, ...
                samplingScenarioConfig.scen_mode,samplingScenarioConfig, ...
                'sampling');

            samplingData = struct();
            samplingData.ct = ctSampling;
            samplingData.cst = cstSampling;
            samplingData.multScen = multScen;
            samplingData.ctScenProb = multScen.ctScenProb;
            samplingData.scenarioMode = samplingScenarioConfig.scen_mode;
            samplingData.wcSigma = samplingScenarioConfig.wcSigma;
            samplingData.planSet = planSet.metadata;
            samplingData.samplingConfig = planSet.samplingConfig;
            samplingData.structureNormalizationReport = ...
                samplingNormalizationReport;
            samplingData.scenarioBasis = ...
                planWorkflow.sampling.SamplingPlanSet.scenarioBasis( ...
                planSet,samplingScenarioConfig,multScen.ctScenProb);

            resources = planWorkflow.config.Resources.fromRunConfig(runConfig);
            cachePath = ...
                planWorkflow.persistence.SamplingPayloadArtifact.cachePath( ...
                runConfig);
            compactAfterUnit = resources.sampling.compactAfterUnit && ...
                ~isempty(cachePath);
            if compactAfterUnit
                samplingData = ...
                    planWorkflow.persistence.SamplingPayloadArtifact.compactRootPayload( ...
                    samplingData,runConfig,cachePath);
            end

            robustSampleIx = 0;
            for planIx = 1:numel(planSet.entries)
                entry = planSet.entries(planIx);
                completedPlans = planIx - 1;
                if strcmp(entry.role,'reference')
                    unitIx = 1;
                else
                    unitIx = robustSampleIx + 1;
                end
                unitKey = ...
                    planWorkflow.stages.SamplingStage.sampleUnitKey( ...
                    entry,planIx,unitIx);
                unitInfo = ...
                    planWorkflow.stages.SamplingStage.sampleUnitInfo( ...
                    entry,planIx,unitKey);
                logFn(sprintf('Sampling %s.',entry.label));
                planWorkflow.sampling.SamplingService.reportPlanProgress( ...
                    context,completedPlans,sampledPlanCount, ...
                    sprintf('Sampling %s.',entry.label));
                [sample,reusedSample] = ...
                    planWorkflow.stages.SamplingStage.cachedSampleUnit( ...
                    runConfig,cachePath,unitKey,unitInfo,compactAfterUnit);
                if reusedSample
                    logFn(sprintf(['Sampling %s already has a complete ', ...
                        'payload artifact; reusing cached unit.'], ...
                        entry.label));
                else
                    sample = context.runMeasuredPlanTask( ...
                        'sample',entry.role,entry.label,'sampling', ...
                        entry.planId,entry.variantId, ...
                        @() planWorkflow.sampling.SamplingService.samplePlanWithProgress( ...
                        context,ctSampling,cstSampling,entry.stf,entry.pln, ...
                        entry.resultGUI,multScen,completedPlans, ...
                        sampledPlanCount,entry.label));
                    sample = ...
                        planWorkflow.stages.SamplingStage.attachSampleMetadata( ...
                        sample,entry);
                    if compactAfterUnit
                        sample = ...
                            planWorkflow.persistence.SamplingPayloadArtifact.compactSampleUnit( ...
                            sample,runConfig,cachePath,unitKey,unitInfo);
                    end
                end
                if strcmp(entry.role,'reference')
                    samplingData.reference = sample;
                else
                    robustSampleIx = robustSampleIx + 1;
                    if robustSampleIx == 1
                        samplingData.robust = cell(1, ...
                            sampledPlanCount - 1);
                    end
                    samplingData.robust{robustSampleIx} = sample;
                end
                planWorkflow.sampling.SamplingService.reportPlanProgress( ...
                    context,planIx,sampledPlanCount, ...
                    sprintf('%s sampled.',entry.label));
            end

            context.reportGuiStageProgress('sample',1, ...
                'Sampling completed.');

            patch = struct();
            patch.runConfig = struct('analysis',analysis);
            patch.data = struct('sampling',samplingData);
        end
    end

    methods (Static, Access = private)
        function [sample,reused] = cachedSampleUnit(runConfig,cachePath, ...
                unitKey,unitInfo,enabled)
            sample = struct();
            reused = false;
            if ~enabled
                return;
            end
            [sample,reused] = ...
                planWorkflow.persistence.SamplingPayloadArtifact.cachedSampleUnit( ...
                runConfig,cachePath,unitKey,unitInfo);
        end

        function sample = attachSampleMetadata(sample,entry)
            sample.label = entry.label;
            sample.planId = entry.planId;
            sample.variantId = entry.variantId;
            sample.role = entry.role;
        end

        function unitInfo = sampleUnitInfo(entry,unitIndex,unitKey)
            unitInfo = struct();
            unitInfo.role = char(entry.role);
            unitInfo.planId = char(entry.planId);
            unitInfo.variantId = char(entry.variantId);
            unitInfo.label = char(entry.label);
            unitInfo.unitIndex = unitIndex;
            unitInfo.unitKey = char(unitKey);
        end

        function unitKey = sampleUnitKey(entry,unitIndex,roleIndex)
            if strcmp(entry.role,'reference')
                rolePart = 'reference';
            else
                rolePart = sprintf('robust_%d',roleIndex);
            end
            unitKey = sprintf('%s_%03d_%s_%s',rolePart,unitIndex, ...
                planWorkflow.stages.SamplingStage.safeName(entry.planId), ...
                planWorkflow.stages.SamplingStage.safeName(entry.variantId));
        end

        function value = safeName(value)
            value = regexprep(char(value),'[^A-Za-z0-9_.-]','_');
            if isempty(value)
                value = 'unnamed';
            end
        end
    end

end
