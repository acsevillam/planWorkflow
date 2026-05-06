classdef PrepareStage
    % PrepareStage Builds optimization geometry, objectives, plan and stf.

    methods (Static)
        function context = workflowContext(varargin)
            if nargin == 3 && ...
                    planWorkflow.stages.WorkflowRuntime.isRuntime(varargin{3})
                runConfig = varargin{1};
                data = varargin{2};
                runtime = varargin{3};
                context = planWorkflow.stages.PrepareStage.context( ...
                    runConfig,data,runtime.taskRunner(),runtime.logFn(), ...
                    planWorkflow.stages.ContextValidator.planTemplate( ...
                    runConfig,data));
                return;
            end
            [runConfig,data,taskRunner,logFn,planTemplate] = varargin{:};
            context = planWorkflow.stages.PrepareStage.context( ...
                runConfig,data,taskRunner,logFn,planTemplate);
        end

        function context = context(runConfig,data,taskRunner,logFn, ...
                planTemplate)
            data = planWorkflow.stages.ContextValidator.dataSlice( ...
                data,{}, {},'prepare');
            context = planWorkflow.stages.ContextValidator.base( ...
                'prepare',runConfig,data,taskRunner,logFn);
            context.planTemplate = planTemplate;
            planWorkflow.stages.ContextValidator.requireFields( ...
                context,{'planTemplate'},'prepare');
        end

        function patch = run(context)
            prepared = planWorkflow.precompute.PrepareService.run(context);

            patch = struct();
            patch.runConfig = struct('analysis',prepared.analysis);
            patch.data = struct();
            patch.data.ct = prepared.ct;
            patch.data.cst = prepared.cst;
            patch.data.pln = prepared.pln;
            patch.data.stf = prepared.stf;
            patch.data.quantityOpt = prepared.quantityOpt;
            patch.data.quantityVis = prepared.quantityVis;
            patch.data.objectiveInfo = prepared.objectiveInfo;
            patch.data.structureNormalizationReport = ...
                prepared.structureNormalizationReport;
            patch.data.planTemplate = context.planTemplate;
            patch.data.planTemplateHash = context.runConfig.plan_template_hash;
        end
    end
end
