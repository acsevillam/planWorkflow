classdef BeamSelection
    % BeamSelection Applies template beam/radiation-mode selection rules.

    methods (Static)
        function radiationModes = radiationModeOptions( ...
                template,includeOtherRadiationModes)
            if nargin < 2
                includeOtherRadiationModes = false;
            end
            radiationModes = ...
                planWorkflow.templates.BeamSelection.templateRadiationModes( ...
                template);
            if includeOtherRadiationModes
                radiationModes = [radiationModes ...
                    planWorkflow.matRadCapabilitiesReader.supportedRadiationModes()];
            end
            radiationModes = ...
                planWorkflow.templates.BeamSelection.uniqueTextValues( ...
                radiationModes);
        end

        function radiationModes = templateRadiationModes(template)
            if ~isfield(template,'radiationModes') || ...
                    isempty(template.radiationModes)
                error(['planWorkflow:templates:BeamSelection:' ...
                    'MissingRadiationModes'], ...
                    'Plan template "%s" must define radiationModes.', ...
                    char(template.id));
            end
            radiationModes = ...
                planWorkflow.templates.PlanTemplate.radiationModeIds( ...
                template);
        end

        function runConfig = applyTemplateDefaults( ...
                runConfig,template,forceDefaults)
            if nargin < 3
                forceDefaults = false;
            end

            beamIds = planWorkflow.templates.BeamSelection.beamSetIds( ...
                template);
            radiationModes = ...
                planWorkflow.templates.BeamSelection.templateRadiationModes( ...
                template);
            if ~isfield(runConfig,'radiationMode') || ...
                    isempty(runConfig.radiationMode)
                runConfig.radiationMode = radiationModes{1};
            end

            usesTemplateMode = any(strcmp(char(runConfig.radiationMode), ...
                radiationModes));
            if usesTemplateMode
                if forceDefaults || ~isfield(runConfig,'plan_beams') || ...
                        isempty(runConfig.plan_beams) || ...
                        ~any(strcmp(char(runConfig.plan_beams),beamIds))
                    runConfig.plan_beams = ...
                        planWorkflow.templates.PlanTemplate.defaultBeamSetForRadiationMode( ...
                        template,runConfig.radiationMode);
                end
                if forceDefaults || ~isfield(runConfig,'machine') || ...
                        isempty(runConfig.machine)
                    runConfig.machine = ...
                        planWorkflow.templates.PlanTemplate.defaultMachineForRadiationMode( ...
                        template,runConfig.radiationMode);
                end
                if forceDefaults || ~isfield(runConfig,'bioModel') || ...
                        isempty(runConfig.bioModel)
                    runConfig.bioModel = ...
                        planWorkflow.templates.PlanTemplate.defaultBioModelForRadiationMode( ...
                        template,runConfig.radiationMode);
                end
                runConfig = ...
                    planWorkflow.plan.DoseQuantityResolver.applyDefaultToRunConfig( ...
                    runConfig,forceDefaults);
                return;
            end

            if ~isfield(runConfig,'plan_beams') || ...
                    isempty(runConfig.plan_beams) || ...
                    ~any(strcmp(char(runConfig.plan_beams),beamIds))
                runConfig.plan_beams = beamIds{1};
            end
            if forceDefaults || ~isfield(runConfig,'machine') || ...
                    isempty(runConfig.machine)
                machines = ...
                    planWorkflow.matRadCapabilitiesReader.supportedMachines( ...
                    runConfig.radiationMode);
                runConfig.machine = machines{1};
            end
            if forceDefaults || ~isfield(runConfig,'bioModel') || ...
                    isempty(runConfig.bioModel)
                bioModels = ...
                    planWorkflow.matRadCapabilitiesReader.supportedBioModels( ...
                    runConfig.radiationMode);
                runConfig.bioModel = bioModels{1};
            end
            runConfig = ...
                planWorkflow.plan.DoseQuantityResolver.applyDefaultToRunConfig( ...
                runConfig,forceDefaults);
        end

        function radiationModes = upsertRadiationModeSpec( ...
                radiationModes,radiationMode,defaultBeamSet,machine,bioModel)
            spec = struct( ...
                'id',char(radiationMode), ...
                'defaultBeamSet',char(defaultBeamSet), ...
                'machine',char(machine), ...
                'bioModel',char(bioModel));
            if isempty(radiationModes)
                radiationModes = spec;
                return;
            end

            ids = cell(1,numel(radiationModes));
            for i = 1:numel(radiationModes)
                ids{i} = char(radiationModes(i).id);
            end
            ix = find(strcmp(ids,spec.id),1);
            if isempty(ix)
                radiationModes(end + 1) = spec;
            else
                radiationModes(ix) = spec;
            end
        end

        function beamIds = beamSetIds(template)
            beamIds = ...
                planWorkflow.templates.BeamSelection.textFieldCell( ...
                template.beamSets,'id');
        end
    end

    methods (Static, Access = private)
        function values = textFieldCell(structArray,fieldName)
            values = {};
            if isempty(structArray)
                return;
            end
            for i = 1:numel(structArray)
                if isfield(structArray(i),fieldName) && ...
                        ~isempty(structArray(i).(fieldName))
                    values{end + 1} = char(structArray(i).(fieldName)); %#ok<AGROW>
                end
            end
        end

        function values = uniqueTextValues(values)
            values = ...
                planWorkflow.templates.BeamSelection.textArrayToCell( ...
                values);
            values = unique(values,'stable');
        end

        function values = textArrayToCell(values)
            if isempty(values)
                values = {};
            elseif ischar(values) || isstring(values)
                values = cellstr(values);
            elseif iscell(values)
                values = cellfun(@char,values,'UniformOutput',false);
            else
                values = cellfun(@char,{values.id},'UniformOutput',false);
            end
        end
    end
end
