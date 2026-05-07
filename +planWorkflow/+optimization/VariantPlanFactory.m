classdef VariantPlanFactory
    % VariantPlanFactory Builds the canonical pln for a robust variant.

    methods (Static)
        function pln = build(robustData,variantIx)
            pln = planWorkflow.precompute.IntervalDoseInfluence.optimizationPlan( ...
                robustData);
            pln = planWorkflow.config.RobustStrategySpec.applyVariantToPlan( ...
                pln,robustData.planConfig,variantIx);
            if ~isfield(robustData,'usesNominalDijForOptimization') || ...
                    ~logical(robustData.usesNominalDijForOptimization)
                pln = ...
                    planWorkflow.optimization.PlanOptimizationService.apply4DConfig( ...
                    pln,robustData.planConfig);
            end
        end
    end
end
