classdef NoneStrategy < planWorkflow.robustness.AbstractStrategy
    % NoneStrategy No-op robust objective strategy.

    methods
        function obj = NoneStrategy()
            obj.name = 'none';
        end

        function [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig) %#ok<INUSD>
        end
    end
end
