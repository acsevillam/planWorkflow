classdef CheapCOWCStrategy < planWorkflow.robustness.AbstractStrategy
    % CheapCOWCStrategy Applies c-COWC robustness with cheap bounds.

    properties (Access = private)
        includeOAR
    end

    methods
        function obj = CheapCOWCStrategy(name,includeOAR)
            obj.name = name;
            obj.includeOAR = includeOAR;
        end

        function [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig)
            obj.validateCheapBounds(runConfig);
            pln.propOpt.useMaxApprox = 'cheapCOWC';
            pln.propOpt.p1 = runConfig.p1;
            pln.propOpt.p2 = runConfig.p2;

            cst = obj.setTargetRobustness(cst,objectiveInfo.ixTarget,'COWC');
            if obj.includeOAR
                cst = obj.setOARRobustness(cst,objectiveInfo.oarStructSel,'COWC');
            end
        end
    end

    methods (Access = private)
        function validateCheapBounds(obj,runConfig) %#ok<INUSD>
            if ~isfield(runConfig,'p1') || ~isfield(runConfig,'p2')
                error('planWorkflow:robustness:CheapCOWCStrategy:MissingBounds', ...
                    'c-COWC strategies require p1 and p2 in the workflow configuration.');
            end
        end
    end
end
