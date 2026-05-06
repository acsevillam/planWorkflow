classdef PlanOptimizationService
    % PlanOptimizationService Owns optimization plan construction/execution.

    methods (Static)
        function resultGUI = runFluenceOptimization( ...
                runConfig,dij,cst,pln,initialWeights)
            pln.propOpt.optimizer = runConfig.optimizer;
            if nargin >= 5 && ~isempty(initialWeights)
                resultGUI = matRad_fluenceOptimization( ...
                    dij,cst,pln,initialWeights);
            else
                resultGUI = matRad_fluenceOptimization(dij,cst,pln);
            end
        end

        function pln = apply4DConfig(pln,planConfig)
            if ~isfield(pln,'propOpt') || ~isstruct(pln.propOpt)
                pln.propOpt = struct();
            end

            if planWorkflow.optimization.PlanOptimizationService.optimization4DEnabled( ...
                    planConfig)
                pln.propOpt.scen4D = planConfig.optimization4D.scen4D;
            elseif isfield(pln.propOpt,'scen4D')
                pln.propOpt = rmfield(pln.propOpt,'scen4D');
            end
        end

        function tf = optimization4DEnabled(planConfig)
            tf = isstruct(planConfig) && ...
                isfield(planConfig,'optimization4D') && ...
                isstruct(planConfig.optimization4D) && ...
                isfield(planConfig.optimization4D,'enabled') && ...
                logical(planConfig.optimization4D.enabled);
        end
    end
end
