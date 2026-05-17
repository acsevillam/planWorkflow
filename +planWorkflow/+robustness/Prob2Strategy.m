classdef Prob2Strategy < planWorkflow.robustness.AbstractStrategy
    % Prob2Strategy Applies PROB2 objective settings.

    methods
        function obj = Prob2Strategy()
            obj.name = 'PROB2';
        end

        function tf = requiresProbDij(obj) %#ok<MANU>
            tf = true;
        end

        function [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig) %#ok<INUSD>
        end
    end
end
