classdef ParameterPanelLayout
    % ParameterPanelLayout Shared normalized geometry for parameter panels.

    methods (Static)
        function height = controlHeight()
            height = 0.055;
        end

        function stride = baseRowStride()
            stride = 0.068;
        end

        function height = sectionHeight()
            height = 0.052;
        end

        function stride = sectionRowStride()
            stride = 0.076;
        end

        function height = controlHeightForType(type)
            switch char(type)
                case 'multiSelect'
                    height = 0.16;
                case 'section'
                    height = planWorkflow.gui.ParameterPanelLayout.sectionHeight();
                otherwise
                    height = planWorkflow.gui.ParameterPanelLayout.controlHeight();
            end
        end

        function stride = rowStride(spec)
            if planWorkflow.gui.ParameterPanelProjection.isSectionSpec(spec)
                stride = planWorkflow.gui.ParameterPanelLayout.sectionRowStride();
                return;
            end

            baseStep = planWorkflow.gui.ParameterPanelLayout.baseRowStride();
            controlExtra = ...
                planWorkflow.gui.ParameterPanelLayout.controlHeightForType( ...
                spec.type) - ...
                planWorkflow.gui.ParameterPanelLayout.controlHeight();
            noteExtra = 0;
            if isfield(spec,'helpText') && ~isempty(char(spec.helpText))
                noteExtra = ...
                    planWorkflow.gui.TextLayout.helpTextHeightForDisplay( ...
                    planWorkflow.gui.TextLayout.helpTextForDisplay( ...
                    spec.helpText, ...
                    planWorkflow.gui.TextLayout.parameterHelpTextWrapColumn()), ...
                    planWorkflow.gui.TextLayout.parameterHelpTextWrapColumn());
            end
            stride = baseStep + max(controlExtra,noteExtra);
        end
    end
end
