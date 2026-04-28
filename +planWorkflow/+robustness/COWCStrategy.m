classdef COWCStrategy < planWorkflow.robustness.AbstractStrategy
    % COWCStrategy Applies COWC robustness with logsumexp max approximation.

    properties (Access = private)
        includeOAR
    end

    methods
        function obj = COWCStrategy(name,includeOAR)
            obj.name = name;
            obj.includeOAR = includeOAR;
        end

        function [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig) %#ok<INUSD>
            pln.propOpt.useMaxApprox = 'logsumexp';
            cst = obj.setTargetRobustness(cst,objectiveInfo.ixTarget,'COWC');
            if obj.includeOAR
                cst = obj.setOARRobustness(cst,objectiveInfo.oarStructSel,'COWC');
            end
        end
    end
end
