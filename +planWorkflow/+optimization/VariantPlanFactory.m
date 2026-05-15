classdef VariantPlanFactory
    % VariantPlanFactory Builds the canonical pln for a robust variant.

    methods (Static)
        function pln = build(robustData,variantIx)
            optimizationInput = ...
                planWorkflow.precompute.OptimizationInput.requireLight( ...
                robustData,'robust variant plan');
            pln = optimizationInput.pln;
            pln = planWorkflow.config.RobustStrategySpec.applyVariantToPlan( ...
                pln,robustData.planConfig,variantIx);
            if ~planWorkflow.precompute.OptimizationInput.isNominal( ...
                    optimizationInput)
                pln = ...
                    planWorkflow.optimization.PlanOptimizationService.apply4DConfig( ...
                    pln,robustData.planConfig);
            end
        end
    end
end
