classdef ParameterPanelProjection
    % ParameterPanelProjection Tracks active fields for editable GUI panels.

    methods (Static)
        function initialize(panel,specs)
            planWorkflow.gui.ParameterPanelProjection.setVisibleFields( ...
                panel, ...
                planWorkflow.gui.ParameterPanelProjection.specFields(specs));
        end

        function setVisibleFields(panel,visibleFields)
            if isgraphics(panel)
                setappdata(panel,'planWorkflowVisibleFields',visibleFields);
            end
        end

        function fields = visibleFields(panel,specs)
            fields = {};
            if isgraphics(panel)
                fields = getappdata(panel,'planWorkflowVisibleFields');
            end
            if isempty(fields)
                fields = planWorkflow.gui.ParameterPanelProjection.specFields( ...
                    specs);
            end
        end

        function config = removeInactiveFields(config,specs,visibleFields)
            parameterFields = ...
                planWorkflow.gui.ParameterPanelProjection.configFields(specs);
            inactiveFields = setdiff(parameterFields,visibleFields,'stable');
            for i = 1:numel(inactiveFields)
                if isfield(config,inactiveFields{i})
                    config = rmfield(config,inactiveFields{i});
                end
            end
        end

        function config = toConfig(config,tableHandle)
            specs = tableHandle.specs;
            panel = planWorkflow.gui.ParameterPanelProjection.panelHandle( ...
                tableHandle);
            activeFields = ...
                planWorkflow.gui.ParameterPanelProjection.visibleFields( ...
                panel,specs);
            config = ...
                planWorkflow.gui.ParameterPanelProjection.removeInactiveFields( ...
                config,specs,activeFields);
            config = ...
                planWorkflow.gui.ParameterPanelProjection.removeDisplayFields( ...
                config,specs);

            for i = 1:numel(specs)
                if planWorkflow.gui.ParameterPanelProjection.isSectionSpec( ...
                        specs(i)) || ...
                        ~planWorkflow.gui.ParameterPanelProjection.isConfigSpec( ...
                        specs(i)) || ...
                        ~any(strcmp(activeFields,specs(i).field))
                    continue;
                end
                config.(specs(i).field) = ...
                    planWorkflow.gui.ParameterPanelProjection.controlValue( ...
                    tableHandle.controls(i),specs(i));
            end
        end

        function panel = panelHandle(tableHandle)
            panel = [];
            if isstruct(tableHandle) && isfield(tableHandle,'panel')
                panel = tableHandle.panel;
            end
        end

        function config = removeDisplayFields(config,specs)
            displayFields = setdiff( ...
                planWorkflow.gui.ParameterPanelProjection.specFields(specs), ...
                planWorkflow.gui.ParameterPanelProjection.configFields(specs), ...
                'stable');
            for i = 1:numel(displayFields)
                if isfield(config,displayFields{i})
                    config = rmfield(config,displayFields{i});
                end
            end
        end

        function value = fieldValue(tableHandle,fieldName)
            fields = {tableHandle.specs.field};
            fieldIx = find(strcmp(fields,fieldName),1);
            if isempty(fieldIx)
                error('planWorkflow:gui:ParameterPanelProjection:UnknownField', ...
                    'Unknown parameter panel field "%s".',fieldName);
            end
            value = planWorkflow.gui.ParameterPanelProjection.controlValue( ...
                tableHandle.controls(fieldIx),tableHandle.specs(fieldIx));
        end

        function value = controlValue(control,spec)
            style = get(control,'Style');
            if strcmp(style,'listbox')
                values = planWorkflow.gui.ParameterPanelProjection.popupValues( ...
                    control);
                selectedIx = get(control,'Value');
                if isempty(selectedIx)
                    value = [];
                else
                    value = reshape(values(selectedIx),1,[]);
                end
            elseif strcmp(style,'popupmenu')
                values = ...
                    planWorkflow.gui.ParameterPanelProjection.popupValues( ...
                    control);
                value = planWorkflow.gui.ParameterPanelProjection.popupValue( ...
                    values{get(control,'Value')},spec);
            elseif strcmp(style,'checkbox')
                value = logical(get(control,'Value'));
            else
                value = planWorkflow.config.WorkflowParameterSchema.parseValue( ...
                    get(control,'String'),spec.type,spec.field);
            end
        end

        function value = popupValue(text,spec)
            if strcmp(spec.type,'logical')
                value = planWorkflow.config.WorkflowParameterSchema.parseValue( ...
                    text,'logical',spec.field);
            else
                value = char(string(text));
            end
        end

        function values = controlStrings(control)
            values = get(control,'String');
            if ischar(values)
                values = cellstr(values);
            elseif isstring(values)
                values = cellstr(values);
            elseif iscell(values)
                values = cellfun(@char,values,'UniformOutput',false);
            else
                values = cellstr(string(values));
            end
        end

        function values = popupValues(control)
            values = {};
            if isgraphics(control)
                values = getappdata(control,'planWorkflowOptionValues');
            end
            values = planWorkflow.gui.OptionValues.normalizeCellOptionValues( ...
                values);
            if isempty(values)
                values = ...
                    planWorkflow.gui.ParameterPanelProjection.controlStrings( ...
                    control);
            end
        end

        function fields = specFields(specs)
            fields = {};
            for i = 1:numel(specs)
                if planWorkflow.gui.ParameterPanelProjection.isSectionSpec( ...
                        specs(i))
                    continue;
                end
                fields{end + 1} = specs(i).field; %#ok<AGROW>
            end
        end

        function fields = configFields(specs)
            fields = {};
            for i = 1:numel(specs)
                if planWorkflow.gui.ParameterPanelProjection.isSectionSpec( ...
                        specs(i)) || ...
                        ~planWorkflow.gui.ParameterPanelProjection.isConfigSpec( ...
                        specs(i))
                    continue;
                end
                fields{end + 1} = specs(i).field; %#ok<AGROW>
            end
        end

        function tf = isSectionSpec(spec)
            tf = isfield(spec,'type') && strcmp(spec.type,'section');
        end

        function tf = isConfigSpec(spec)
            tf = true;
            if isfield(spec,'isConfigField')
                tf = logical(spec.isConfigField);
            end
        end
    end
end
