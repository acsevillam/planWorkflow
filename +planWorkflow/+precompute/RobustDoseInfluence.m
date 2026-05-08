classdef RobustDoseInfluence
    % RobustDoseInfluence Owns robust dij payload semantics.

    methods (Static)
        function robustData = attach(robustData,dij)
            robustData.dij = dij;
            if ~planWorkflow.precompute.RobustDoseInfluence.isScenarioFreePlan( ...
                    robustData)
                robustData.dijRobust = dij;
            end
        end
    end

    methods (Static, Access = private)
        function tf = isScenarioFreePlan(robustData)
            tf = isstruct(robustData) && ...
                isfield(robustData,'planConfig') && ...
                isstruct(robustData.planConfig) && ...
                ((isfield(robustData.planConfig,'requiresIntervalDij') && ...
                logical(robustData.planConfig.requiresIntervalDij)) || ...
                (isfield(robustData.planConfig,'requiresProb2Dij') && ...
                logical(robustData.planConfig.requiresProb2Dij)));
        end
    end
end
