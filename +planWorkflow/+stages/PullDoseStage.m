classdef PullDoseStage
    % PullDoseStage Runs reference and robust dose-pulling workflows.

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
            else
                [runConfig,data,taskRunner,logFn,planTemplate] = varargin{:};
            end
            dosePullingContext = ...
                planWorkflow.precompute.DosePulling.defaultContext( ...
                runConfig,logFn);
            context = planWorkflow.stages.PullDoseStage.context( ...
                runConfig,data,taskRunner,logFn,planTemplate, ...
                dosePullingContext);
        end

        function context = context(runConfig,data,taskRunner,logFn, ...
                planTemplate,dosePullingContext)
            data = planWorkflow.stages.ContextValidator.dataSlice( ...
                data,{'ct','cst','dij','stf','pln'}, ...
                {'robustPlans','dosePulling','objectiveInfo','quantityOpt'}, ...
                'pullDose');
            context = planWorkflow.stages.ContextValidator.base( ...
                'pullDose',runConfig,data,taskRunner,logFn);
            context.planTemplate = planTemplate;
            context.dosePulling = dosePullingContext;
            planWorkflow.stages.ContextValidator.requireFields( ...
                context,{'planTemplate','dosePulling'},'pullDose');
        end

        function patch = run(context)
            data = context.data;
            runConfig = context.runConfig;
            logFn = context.log;

            dosePulling = struct();
            if ~runConfig.dose_pulling1 && ~runConfig.dose_pulling2
                logFn('Dose pulling is disabled for this workflow.');
                patch = struct();
                patch.data = struct();
                patch.data.dosePulling = dosePulling;
                return;
            end

            if runConfig.dose_pulling1
                reference = ...
                    planWorkflow.config.RobustPlanConfig.referenceFromRunConfig( ...
                    runConfig);
                referenceLabel = ...
                    planWorkflow.results.PlanLabels.referencePlanDisplayLabel( ...
                    reference);
                logFn(sprintf(['Running dose pulling step 1 on %s ' ...
                    'objectives.'],referenceLabel));
                [data.cst,referenceReport] = ...
                    context.runMeasuredPlanTask( ...
	                    'pullDose','reference',referenceLabel,'dosePulling', ...
	                    '','',@() planWorkflow.precompute.DosePulling.runReference( ...
	                    context.dosePulling,data.ct,data.cst,data.dij, ...
	                    data.stf,data.pln));
                dosePulling.reference = referenceReport;
                planWorkflow.precompute.DosePullingReportLogger.logReference( ...
                    logFn,referenceReport);

                if planWorkflow.stages.PullDoseStage.hasRobustDataPlans(data)
                    for robustPlanIx = 1:numel(data.robustPlans)
                        data.robustPlans{robustPlanIx} = ...
                            planWorkflow.precompute.RobustDataFactory.refreshAfterReferencePulling( ...
                            runConfig,context.planTemplate, ...
                            data.robustPlans{robustPlanIx},data);
                    end
                end
            end

            if runConfig.dose_pulling2
                if ~planWorkflow.stages.PullDoseStage.hasRobustDataPlans(data)
                    error('planWorkflow:Engine:DosePullingNeedsRobustData', ...
                        'dose_pulling2 requires a robust optimization strategy.');
                end

                logFn('Running dose pulling step 2 on robust objectives.');
                dosePulling.robust = cell(1,numel(data.robustPlans));
                for robustPlanIx = 1:numel(data.robustPlans)
                    robustData = data.robustPlans{robustPlanIx};
                    [robustData,robustReport] = ...
                        context.runMeasuredPlanTask( ...
                        'pullDose','robust', ...
                        char(robustData.planConfig.label), ...
	                        'dosePulling',char(robustData.planConfig.id), ...
	                        '',@() planWorkflow.precompute.DosePulling.runRobust( ...
	                        context.dosePulling,robustData));
                    data.robustPlans{robustPlanIx} = robustData;
                    dosePulling.robust{robustPlanIx} = robustReport;
                    planWorkflow.precompute.DosePullingReportLogger.logRobust( ...
                        logFn,robustReport);
                end
            end

            patch = struct();
            patch.data = struct();
            patch.data.cst = data.cst;
            patch.data.dosePulling = dosePulling;
            if isfield(data,'robustPlans')
                patch.data.robustPlans = data.robustPlans;
            end
        end
	    end

	    methods (Static, Access = private)
	        function tf = hasRobustDataPlans(data)
	            tf = isfield(data,'robustPlans') && ~isempty(data.robustPlans);
	        end
    end
end
