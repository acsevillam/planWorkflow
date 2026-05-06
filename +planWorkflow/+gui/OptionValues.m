classdef OptionValues
    % OptionValues Shared helpers for GUI option and text values.

    methods (Static)
        function [values,selectedIx] = optionSetWithCurrent( ...
                values,currentValue)
            currentValue = char(currentValue);
            if isempty(values)
                values = {currentValue};
            end
            selectedIx = ...
                planWorkflow.gui.OptionValues.selectedOptionIndex( ...
                values,currentValue);
            if isempty(selectedIx)
                values{end + 1} = currentValue;
                selectedIx = numel(values);
            end
        end

        function selectedIx = selectedOptionIndex(values,currentValue)
            currentText = planWorkflow.gui.OptionValues.valueToText( ...
                currentValue);
            selectedIx = find(strcmp(values,currentText),1);
        end

        function values = optionValuesWithCurrent(values,currentValue)
            currentText = planWorkflow.gui.OptionValues.valueToText( ...
                currentValue);
            if isempty(values)
                values = {currentText};
                return;
            end
            if ~any(strcmp(values,currentText))
                values{end + 1} = currentText;
            end
        end

        function values = optionValuesWithCurrentCell(values,currentValues)
            currentValues = ...
                planWorkflow.gui.OptionValues.normalizeCellOptionValues( ...
                currentValues);
            for i = 1:numel(currentValues)
                if ~any(strcmp(values,currentValues{i}))
                    values{end + 1} = currentValues{i}; %#ok<AGROW>
                end
            end
        end

        function values = uniqueTextValues(values)
            values = planWorkflow.gui.OptionValues.textArrayToCell(values);
            [~,ix] = unique(values,'stable');
            values = values(sort(ix));
        end

        function values = textArrayToCell(values)
            if iscell(values)
                values = cellfun(@char,values(:)','UniformOutput',false);
            elseif isstring(values)
                values = cellstr(values(:)');
            elseif ischar(values)
                values = {values};
            else
                error('planWorkflow:gui:OptionValues:InvalidTextArray', ...
                    'Expected a text array.');
            end
        end

        function values = normalizeCellOptionValues(values)
            if isempty(values)
                values = {};
            elseif ischar(values) || isstring(values)
                values = cellstr(string(values));
            elseif iscell(values)
                values = cellfun(@char,values,'UniformOutput',false);
            else
                values = {char(string(values))};
            end
            values = values(~cellfun('isempty',values));
        end

        function selectedIx = selectedMultiOptionIndices( ...
                values,currentValues)
            currentValues = ...
                planWorkflow.gui.OptionValues.normalizeCellOptionValues( ...
                currentValues);
            selectedIx = [];
            for i = 1:numel(currentValues)
                ix = find(strcmp(values,currentValues{i}),1);
                if ~isempty(ix)
                    selectedIx(end + 1) = ix; %#ok<AGROW>
                end
            end
        end

        function value = multiSelectConfigValue(values,selectedIx)
            if isempty(selectedIx)
                value = [];
                return;
            end
            value = values(selectedIx);
            value = reshape(value,1,[]);
        end

        function values = targetsToCell(targets)
            if iscell(targets)
                values = cell(1,numel(targets));
                for i = 1:numel(targets)
                    values{i} = char(targets{i});
                end
            elseif isstring(targets)
                values = cellstr(targets);
            else
                values = {char(targets)};
            end
        end

        function text = valueToText(value)
            if ischar(value)
                text = value;
            elseif isstring(value)
                text = char(value);
            elseif islogical(value)
                if isscalar(value)
                    text = char(string(value));
                else
                    text = mat2str(value);
                end
            elseif isnumeric(value)
                text = mat2str(value);
            elseif iscell(value)
                text = planWorkflow.gui.OptionValues.joinCellText(value);
            elseif isstruct(value)
                text = jsonencode(value);
            elseif isempty(value)
                text = '[]';
            else
                text = char(string(value));
            end
        end

        function text = fieldText(spec,fieldName)
            if ~isfield(spec,fieldName) || isempty(spec.(fieldName))
                text = '';
                return;
            end
            text = planWorkflow.gui.OptionValues.valueToText( ...
                spec.(fieldName));
        end

        function text = joinCellText(values)
            if isempty(values)
                text = '[]';
                return;
            end
            if ischar(values) || isstring(values)
                values = cellstr(values);
            end
            values = cellfun(@char,values,'UniformOutput',false);
            text = strjoin(values,', ');
        end
    end
end
