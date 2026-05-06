classdef PlanAnalysis
    % PlanAnalysis Reference/robust plan indicator and DVH evaluation.

    methods (Static)
        function [resultGUI,dvh,qi] = run(analysisConfig,ct,cst,stf,pln, ...
                resultGUI,showFigures,optimizationQuantity)
            if nargin < 7
                showFigures = true;
            end
            if nargin < 8
                optimizationQuantity = '';
            end

            quantity = planWorkflow.analysis.PlanAnalysis.resolveQuantity( ...
                pln,optimizationQuantity);
            if showFigures
                resultGUI = matRad_planAnalysis(resultGUI,ct,cst,stf,pln, ...
                    'quantity',quantity, ...
                    'evaluationMode',analysisConfig.evaluationMode, ...
                    'refGy',[], ...
                    'refVol',[], ...
                    'doseWindow',analysisConfig.doseWindowDvh);
                dvh = resultGUI.dvh;
                qi = resultGUI.qi;
            else
                [dvh,qi] = planWorkflow.analysis.PlanAnalysis.calculateIndicators( ...
                    cst,pln,resultGUI,quantity);
                resultGUI.dvh = dvh;
                resultGUI.qi = qi;
            end
            endpointQuantity = ...
                planWorkflow.plan.DoseQuantityResolver.visualFromPlan( ...
                pln,quantity);
            resultGUI.endpointQuantity = endpointQuantity;
            if ~strcmp(endpointQuantity,quantity) && ...
                    isfield(resultGUI,endpointQuantity)
                resultGUI.endpointDvh = matRad_calcDVH( ...
                    cst,resultGUI.(endpointQuantity),'cum');
            end
            resultGUI.analysisQuantity = quantity;
            resultGUI.evaluationModeBase = 'perFraction';
            if isfield(pln,'numOfFractions') && ~isempty(pln.numOfFractions)
                resultGUI.numOfFractions = pln.numOfFractions;
            end
            [resultGUI.evaluationScale,resultGUI.evaluationMode] = ...
                matRad_convertToEvaluationMode( ...
                1,pln,analysisConfig.evaluationMode);
        end

        function quantity = resolveQuantity(pln,optimizationQuantity)
            if nargin < 2
                optimizationQuantity = '';
            end
            try
                quantity = planWorkflow.plan.DoseQuantityResolver.fromPlan( ...
                    pln,optimizationQuantity);
            catch ME
                if strcmp(ME.identifier, ...
                        'planWorkflow:plan:DoseQuantityResolver:MissingQuantity')
                    error(['planWorkflow:analysis:PlanAnalysis:' ...
                        'MissingOptimizationQuantity'],ME.message);
                end
                rethrow(ME);
            end
        end

        function [dvh,qi] = calculateIndicators(cst,pln,resultGUI,quantity)
            if ~isfield(resultGUI,quantity)
                error('planWorkflow:analysis:PlanAnalysis:UnknownQuantity', ...
                    'Unknown quantity "%s" to analyse.',quantity);
            end

            doseCube = resultGUI.(quantity);
            dvh = matRad_calcDVH(cst,doseCube,'cum');
            qi = matRad_calcQualityIndicators(cst,pln,doseCube,[],[]);
        end
    end
end
