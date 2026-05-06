classdef StageExecutor
    % StageExecutor Dispatches workflow stages from canonical descriptors.

    methods (Static)
        function patch = run(stageName,runConfig,data,runtime)
            planWorkflow.stages.WorkflowRuntime.require(runtime);
            descriptor = ...
                planWorkflow.config.StageConfigSchema.descriptor(stageName);
            context = feval([descriptor.stageClass '.workflowContext'], ...
                runConfig,data,runtime);
            patch = feval([descriptor.stageClass '.run'],context);
        end
    end
end
