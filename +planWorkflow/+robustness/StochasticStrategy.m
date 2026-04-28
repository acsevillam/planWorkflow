classdef StochasticStrategy < planWorkflow.robustness.AbstractStrategy
    % StochasticStrategy Applies STOCH robustness to objectives.

    properties (Access = private)
        includeOAR
    end

    methods
        function obj = StochasticStrategy(name,includeOAR)
            obj.name = name;
            obj.includeOAR = includeOAR;
        end

        function [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig) %#ok<INUSD>
            cst = obj.setTargetRobustness(cst,objectiveInfo.ixTarget,'STOCH');
            if obj.includeOAR
                cst = obj.setOARRobustness(cst,objectiveInfo.oarStructSel,'STOCH');
            end
        end
    end
end
