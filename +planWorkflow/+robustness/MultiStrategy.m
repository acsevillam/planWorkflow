classdef MultiStrategy < planWorkflow.robustness.AbstractStrategy
    % MultiStrategy Summary marker for workflows with multiple robust plans.

    methods
        function obj = MultiStrategy()
            obj.name = 'multi';
        end

        function [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig) %#ok<INUSD>
        end
    end
end
