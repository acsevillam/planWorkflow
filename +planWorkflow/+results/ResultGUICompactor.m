classdef ResultGUICompactor
    % ResultGUICompactor Removes reproducible dose cubes from optimization results.

    methods (Static)
        function data = compactOptimizationResults(data)
            if ~isstruct(data) || isempty(data)
                return;
            end
            if isfield(data,'resultGUIReference')
                data.resultGUIReference = ...
                    planWorkflow.results.ResultGUICompactor.compact( ...
                    data.resultGUIReference);
            end
            if isfield(data,'resultGUI')
                data.resultGUI = ...
                    planWorkflow.results.ResultGUICompactor.compact( ...
                    data.resultGUI);
            end
            if isfield(data,'robustPlans') && iscell(data.robustPlans)
                for planIx = 1:numel(data.robustPlans)
                    robustData = data.robustPlans{planIx};
                    if isstruct(robustData) && ...
                            isfield(robustData,'variantResults')
                        robustData.variantResults = ...
                            planWorkflow.results.ResultGUICompactor.compactVariantResults( ...
                            robustData.variantResults);
                        data.robustPlans{planIx} = robustData;
                    end
                end
            end
        end

        function results = compactVariantResults(results)
            if ~isstruct(results)
                return;
            end
            for resultIx = 1:numel(results)
                if isfield(results(resultIx),'resultGUI')
                    results(resultIx).resultGUI = ...
                        planWorkflow.results.ResultGUICompactor.compact( ...
                        results(resultIx).resultGUI);
                end
            end
        end

        function resultGUI = compact(resultGUI)
            if ~isstruct(resultGUI) || isempty(resultGUI)
                return;
            end
            names = fieldnames(resultGUI);
            remove = false(size(names));
            for nameIx = 1:numel(names)
                fieldName = names{nameIx};
                fieldValue = resultGUI.(fieldName);
                remove(nameIx) = ...
                    planWorkflow.results.ResultGUICompactor.isDoseCubeField( ...
                    fieldName,fieldValue);
            end
            if any(remove)
                resultGUI = rmfield(resultGUI,names(remove));
            end
        end
    end

    methods (Static, Access = private)
        function tf = isDoseCubeField(fieldName,fieldValue)
            tf = false;
            if ~(isnumeric(fieldValue) || islogical(fieldValue))
                return;
            end
            quantities = {'physicalDose','doseToWater','effect', ...
                'RBExDose','RBE','LET','BED','alpha','beta', ...
                'alphaDoseCube','SqrtBetaDoseCube'};
            for quantityIx = 1:numel(quantities)
                quantity = quantities{quantityIx};
                if strcmp(fieldName,quantity) || ...
                        startsWith(fieldName,[quantity '_'])
                    tf = true;
                    return;
                end
            end
        end
    end
end
