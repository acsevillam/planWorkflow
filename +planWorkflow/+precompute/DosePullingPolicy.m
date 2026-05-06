classdef DosePullingPolicy
    % DosePullingPolicy Owns stop/update decisions for dose pulling.

    methods (Static)
        function tf = robustNeedsUpdate(runConfig,metrics)
            if isfield(metrics,'isSatisfied')
                tf = ~metrics.isSatisfied;
                return;
            end
            if isfield(metrics,'selectedValues') && isfield(metrics,'limits')
                criteriaValues = metrics.selectedValues;
                limits = metrics.limits;
            else
                criteriaValues = ...
                    planWorkflow.precompute.DosePullingMetrics.selectRobustCriteria( ...
                    runConfig,metrics);
                limits = ...
                    planWorkflow.precompute.DosePullingUtils.expandNumericToCount( ...
                    runConfig.dose_pulling2_limit,numel(criteriaValues), ...
                    'dose_pulling2_limit');
            end
            tf = any(criteriaValues < limits);
        end
    end
end
