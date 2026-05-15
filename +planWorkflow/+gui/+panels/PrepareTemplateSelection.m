classdef PrepareTemplateSelection
    % PrepareTemplateSelection Applies description/template selection rules.

    methods (Static)
        function patch = selectDescription(runConfig,descriptionId, ...
                includeOtherRadiationModes)
            if nargin < 3
                includeOtherRadiationModes = false;
            end
            runConfig.description = char(descriptionId);
            templateIds = ...
                planWorkflow.templates.PlanTemplate.availableTemplateIds( ...
                runConfig.description);
            if isempty(templateIds)
                error('planWorkflow:gui:PlanEditor:MissingTemplates', ...
                    'Description "%s" does not define plan templates.', ...
                    runConfig.description);
            end

            patch = planWorkflow.gui.panels.PrepareTemplateSelection.selectTemplate( ...
                runConfig,templateIds,1,includeOtherRadiationModes);
            patch.templateIds = templateIds;
            patch.selectedTemplateIx = 1;
        end

        function patch = selectTemplate(runConfig,templateIds, ...
                selectedTemplateIx,includeOtherRadiationModes)
            if nargin < 4
                includeOtherRadiationModes = false;
            end
            if selectedTemplateIx < 1 || selectedTemplateIx > numel(templateIds)
                error('planWorkflow:gui:PlanEditor:InvalidTemplateSelection', ...
                    'Selected template index is out of range.');
            end

            runConfig.plan_template = templateIds{selectedTemplateIx};
            template = ...
                planWorkflow.templates.PlanTemplate.loadForDescription( ...
                runConfig.description,runConfig.plan_template);
            radiationModes = ...
                planWorkflow.templates.BeamSelection.radiationModeOptions( ...
                template,includeOtherRadiationModes);
            if ~any(strcmp(runConfig.radiationMode,radiationModes))
                runConfig.radiationMode = radiationModes{1};
            end
            runConfig = ...
                planWorkflow.templates.BeamSelection.applyTemplateDefaults( ...
                runConfig,template,true);

            beamIds = planWorkflow.templates.BeamSelection.beamSetIds( ...
                template);
            selectedBeamIx = find(strcmp(beamIds,runConfig.plan_beams),1);
            if isempty(selectedBeamIx)
                selectedBeamIx = 1;
                runConfig.plan_beams = beamIds{selectedBeamIx};
            end
            [runConfig,template] = ...
                planWorkflow.gui.PlanEditorContract.resetPrecomputeForTemplateSelection( ...
                runConfig,template);

            patch = struct();
            patch.runConfig = runConfig;
            patch.template = template;
            patch.templateIds = templateIds;
            patch.selectedTemplateIx = selectedTemplateIx;
            patch.radiationModes = radiationModes;
            patch.beamIds = beamIds;
            patch.selectedBeamIx = selectedBeamIx;
        end
    end
end
