classdef DosePullingOptimizer
    % DosePullingOptimizer Production optimizer dependency for dose pulling.

    methods (Static)
        function resultGUI = run(runConfig,dij,cst,pln,initialWeights)
            resultGUI = ...
                planWorkflow.optimization.PlanOptimizationService.runFluenceOptimization( ...
                runConfig,dij,cst,pln,initialWeights);
        end
    end
end
