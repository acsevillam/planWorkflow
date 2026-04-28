classdef PlanAnalysis
    % PlanAnalysis Nominal/robust plan indicator and DVH evaluation.

    methods (Static)
        function [resultGUI,dvh,qi] = run(analysisConfig,ct,cst,stf,pln, ...
                resultGUI,showFigures)
            if nargin < 7
                showFigures = true;
            end

            quantity = robOpt.analysis.PlanAnalysis.resolveQuantity(pln,resultGUI);
            if showFigures
                resultGUI = matRad_planAnalysis(resultGUI,ct,cst,stf,pln, ...
                    'quantity',quantity, ...
                    'displayDoseMode',analysisConfig.displayDoseMode, ...
                    'refGy',[], ...
                    'refVol',[], ...
                    'doseWindow',analysisConfig.doseWindowDvh);
                dvh = resultGUI.dvh;
                qi = resultGUI.qi;
            else
                [dvh,qi] = robOpt.analysis.PlanAnalysis.calculateIndicators( ...
                    cst,pln,resultGUI,quantity);
                resultGUI.dvh = dvh;
                resultGUI.qi = qi;
                resultGUI.analysisQuantity = quantity;
                resultGUI.analysisDoseMode = 'perFraction';
            end
        end

        function quantity = resolveQuantity(pln,resultGUI)
            if isfield(pln,'bioParam') && isobject(pln.bioParam) && ...
                    isprop(pln.bioParam,'quantityVis')
                quantity = pln.bioParam.quantityVis;
            elseif isfield(pln,'bioParam') && isstruct(pln.bioParam) && ...
                    isfield(pln.bioParam,'quantityVis')
                quantity = pln.bioParam.quantityVis;
            elseif isfield(resultGUI,'RBExD')
                quantity = 'RBExD';
            else
                quantity = 'physicalDose';
            end

            if isstring(quantity)
                quantity = char(quantity);
            end
        end

        function [dvh,qi] = calculateIndicators(cst,pln,resultGUI,quantity)
            if ~isfield(resultGUI,quantity)
                error('robOpt:analysis:PlanAnalysis:UnknownQuantity', ...
                    'Unknown quantity "%s" to analyse.',quantity);
            end

            doseCube = resultGUI.(quantity);
            dvh = matRad_calcDVH(cst,doseCube,'cum');
            qi = matRad_calcQualityIndicators(cst,pln,doseCube,[],[]);
        end
    end
end
