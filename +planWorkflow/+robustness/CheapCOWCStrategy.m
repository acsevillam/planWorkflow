classdef CheapCOWCStrategy < planWorkflow.robustness.AbstractStrategy
    % CheapCOWCStrategy Applies c-COWC robustness with cheap bounds.

    properties (Access = private)
        includeOAR
    end

    methods
        function obj = CheapCOWCStrategy(name,includeOAR)
            if ~strcmp(char(name),'c-COWC')
                error('planWorkflow:robustness:CheapCOWCStrategy:UnsupportedMode', ...
                    'Unsupported cheap COWC robustness mode "%s".', ...
                    char(name));
            end
            obj.name = name;
            obj.includeOAR = includeOAR;
        end

        function [cst,pln] = apply(obj,cst,pln,objectiveInfo,runConfig)
            obj.validateCheapBounds(runConfig);
            pln.propOpt.useMaxApprox = 'cheapCOWC';
            [p1,p2] = obj.bounds(runConfig);
            pln.propOpt.p1 = p1;
            pln.propOpt.p2 = p2;

            cst = obj.setTargetRobustness(cst,objectiveInfo.ixTarget,'COWC');
            if obj.includeOAR
                cst = obj.setOARRobustness(cst, ...
                    objectiveInfo.robustOarNames,'COWC');
            end
        end
    end

    methods (Access = private)
        function validateCheapBounds(obj,runConfig) %#ok<INUSD>
            hasVariantBounds = isfield(runConfig,'variant') && ...
                isstruct(runConfig.variant) && ...
                isfield(runConfig.variant,'p1') && ...
                isfield(runConfig.variant,'p2');
            if ~hasVariantBounds
                error('planWorkflow:robustness:CheapCOWCStrategy:MissingBounds', ...
                    'c-COWC strategies require p1 and p2 in runConfig.variant.');
            end
        end

        function [p1,p2] = bounds(obj,runConfig) %#ok<INUSD>
            p1 = runConfig.variant.p1;
            p2 = runConfig.variant.p2;
        end
    end
end
