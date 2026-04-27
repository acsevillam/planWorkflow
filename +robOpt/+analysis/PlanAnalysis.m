classdef PlanAnalysis
    % PlanAnalysis Nominal/robust plan indicator and DVH evaluation.

    methods (Static)
        function [resultGUI,dvh,qi] = run(analysisConfig,ct,cst,stf,pln, ...
                resultGUI,showFigures)
            if nargin < 7
                showFigures = true;
            end

            quantity = robOpt.analysis.PlanAnalysis.resolveQuantity(pln,resultGUI);
            doseScale = robOpt.analysis.PlanAnalysis.doseScale( ...
                pln,analysisConfig.doseMode);
            if showFigures
                resultGUI = matRad_planAnalysis(resultGUI,ct,cst,stf,pln, ...
                    'quantity',quantity, ...
                    'doseMode',analysisConfig.doseMode, ...
                    'doseScale',doseScale, ...
                    'refGy',[], ...
                    'refVol',[], ...
                    'doseWindow',analysisConfig.doseWindowDvh);
                dvh = resultGUI.dvh;
                qi = resultGUI.qi;
            else
                [dvh,qi] = robOpt.analysis.PlanAnalysis.calculateIndicators( ...
                    cst,pln,resultGUI,quantity,doseScale);
                resultGUI.dvh = dvh;
                resultGUI.qi = qi;
                resultGUI.analysisQuantity = quantity;
                resultGUI.analysisDoseMode = analysisConfig.doseMode;
                resultGUI.analysisDoseScale = doseScale;
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

        function [dvh,qi] = calculateIndicators(cst,pln,resultGUI, ...
                quantity,doseScale)
            if ~isfield(resultGUI,quantity)
                error('robOpt:analysis:PlanAnalysis:UnknownQuantity', ...
                    'Unknown quantity "%s" to analyse.',quantity);
            end

            doseCube = resultGUI.(quantity) * doseScale;
            dvh = matRad_calcDVH(cst,doseCube,'cum');
            qi = matRad_calcQualityIndicators(cst,pln,doseCube,[],[], ...
                'doseScale',doseScale);
        end

        function doseScale = doseScale(pln,doseMode)
            doseScale = matRad_getAnalysisDoseScale(pln,doseMode,[]);
        end
    end
end
