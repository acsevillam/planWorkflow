classdef TemplateResolver
    % TemplateResolver Resolves template selections without using PlanTemplate.

    methods (Static)
        function template = resolve(runConfig,template)
            if nargin < 2 || isempty(template)
                template = ...
                    planWorkflow.templates.TemplateResolver.loadForDescription( ...
                    runConfig.description,runConfig.plan_template);
            end
            planWorkflow.templates.TemplateResolver.validateRunConfigSelection( ...
                runConfig,template);
            planWorkflow.templates.TemplateResolver.assertAppliesToRunConfig( ...
                runConfig,template);
        end

        function template = loadForDescription(description,templateId)
            description = char(description);
            templateId = ...
                planWorkflow.templates.TemplateResolver.normalizeTemplateId( ...
                templateId);
            templateFolder = fullfile( ...
                planWorkflow.templates.TemplateResolver.templateRoot(), ...
                description,templateId);
            template = planWorkflow.templates.TemplateIO.loadFromFolder( ...
                templateFolder,templateId);
        end

        function templateId = normalizeTemplateId(templateId)
            templateId = strrep(char(templateId),'\','/');
            if isempty(templateId) || contains(templateId,'/')
                error('planWorkflow:templates:PlanTemplate:InvalidTemplateId', ...
                    ['plan_template must be a template id such as "interval2_001"; ' ...
                     'the anatomical location is selected by description.']);
            end
        end

        function validateRunConfigSelection(runConfig,template)
            planWorkflow.templates.TemplateResolver.beamSetById( ...
                template,runConfig.plan_beams);
            radiationModeIds = ...
                planWorkflow.templates.TemplateResolver.radiationModeIds( ...
                template);
            if ~any(strcmp(char(runConfig.radiationMode),radiationModeIds))
                error('planWorkflow:templates:PlanTemplate:RadiationModeMismatch', ...
                    ['runConfig.radiationMode "%s" is not listed in ' ...
                     'template radiationModes.'], ...
                    char(runConfig.radiationMode));
            end
        end

        function assertAppliesToRunConfig(runConfig,template)
            if ~strcmp(char(template.description),char(runConfig.description))
                error('planWorkflow:templates:PlanTemplate:DescriptionMismatch', ...
                    'Plan template "%s" is for description "%s", not "%s".', ...
                    char(template.id),char(template.description), ...
                    char(runConfig.description));
            end
        end

        function beamSet = beamSetById(template,beamSetId)
            ix = planWorkflow.templates.TemplateResolver.findTextField( ...
                template.beamSets,'id',beamSetId);
            if ix == 0
                error('planWorkflow:templates:PlanTemplate:UnknownBeamSet', ...
                    'Plan template "%s" does not define beam set "%s".', ...
                    char(template.id),char(beamSetId));
            end
            beamSet = template.beamSets(ix);
        end

        function objectiveSet = objectiveSet(template,objectiveSetName)
            objectiveSetName = char(objectiveSetName);
            if ~isfield(template,'objectiveSets')
                planWorkflow.templates.TemplateResolver.unknownObjectiveSet( ...
                    template,objectiveSetName);
            end
            if strcmp(objectiveSetName,'reference')
                if ~isfield(template.objectiveSets,'reference')
                    planWorkflow.templates.TemplateResolver.unknownObjectiveSet( ...
                        template,objectiveSetName);
                end
                objectiveSet = template.objectiveSets.reference;
                return;
            end

            robustPlans = ...
                planWorkflow.templates.TemplateResolver.robustObjectiveSets( ...
                template);
            planIx = planWorkflow.templates.TemplateResolver.findTextField( ...
                robustPlans,'id',objectiveSetName);
            if planIx == 0
                planWorkflow.templates.TemplateResolver.unknownObjectiveSet( ...
                    template,objectiveSetName);
            end
            objectiveSet = robustPlans(planIx);
        end

        function ids = radiationModeIds(template)
            ids = cell(1,numel(template.radiationModes));
            for i = 1:numel(template.radiationModes)
                ids{i} = char(template.radiationModes(i).id);
            end
        end

        function spec = radiationModeSpec(template,radiationMode)
            radiationMode = char(radiationMode);
            ids = planWorkflow.templates.TemplateResolver.radiationModeIds( ...
                template);
            ix = find(strcmp(ids,radiationMode),1);
            if isempty(ix)
                error('planWorkflow:templates:PlanTemplate:RadiationModeMismatch', ...
                    ['runConfig.radiationMode "%s" is not listed in ' ...
                     'template radiationModes.'],radiationMode);
            end
            spec = template.radiationModes(ix);
        end

        function robustPlans = robustObjectiveSets(template)
            if isfield(template,'objectiveSets') && ...
                    isfield(template.objectiveSets,'robustPlans')
                robustPlans = template.objectiveSets.robustPlans;
            else
                robustPlans = repmat(struct('id','','label','', ...
                    'structureObjectives',[], ...
                    'ringObjectives',[]),1,0);
            end
        end

        function ix = findTextField(values,fieldName,needle)
            ix = 0;
            for i = 1:numel(values)
                if strcmp(char(values(i).(fieldName)),char(needle))
                    ix = i;
                    return;
                end
            end
        end
    end

    methods (Static, Access = private)
        function root = templateRoot()
            root = fullfile(fileparts(mfilename('fullpath')),'json');
        end

        function unknownObjectiveSet(template,objectiveSetName)
            error('planWorkflow:templates:PlanTemplate:UnknownObjectiveSet', ...
                'Plan template "%s" does not define objective set "%s".', ...
                char(template.id),objectiveSetName);
        end
    end
end
