classdef PlanTemplate
    % PlanTemplate JSON-backed treatment-plan template helpers.

    methods (Static)
        function template = loadForDescription(description,templateId)
            description = char(description);
            templateId = ...
                planWorkflow.templates.TemplateResolver.normalizeTemplateId( ...
                templateId);
            templateFolder = fullfile( ...
                planWorkflow.templates.PlanTemplate.templateRoot(), ...
                description,templateId);
            template = planWorkflow.templates.PlanTemplate.loadFromFolder( ...
                templateFolder,templateId);
        end

        function templateIds = availableTemplateIds(description)
            templateRoot = fullfile( ...
                planWorkflow.templates.PlanTemplate.templateRoot(), ...
                char(description));
            if ~isfolder(templateRoot)
                templateIds = {};
                return;
            end

            entries = dir(templateRoot);
            isTemplateFolder = [entries.isdir] & ...
                ~ismember({entries.name},{'.','..','shared'});
            templateIds = {entries(isTemplateFolder).name};
            templateIds = sort(templateIds);
        end

        function descriptions = availableDescriptions()
            root = planWorkflow.templates.PlanTemplate.templateRoot();
            if ~isfolder(root)
                descriptions = {};
                return;
            end

            entries = dir(root);
            isTemplateDescription = [entries.isdir] & ...
                ~ismember({entries.name},{'.','..'});
            descriptions = {entries(isTemplateDescription).name};
            descriptions = sort(descriptions);
        end

        function templateId = normalizeTemplateId(description,templateId)
            description = char(description); %#ok<NASGU>
            templateId = ...
                planWorkflow.templates.TemplateResolver.normalizeTemplateId( ...
                templateId);
        end

        function template = loadFromFile(templateFile,expectedId)
            templateFile = char(templateFile);
            expectedId = char(expectedId);

            if ~isfile(templateFile)
                error('planWorkflow:templates:PlanTemplate:UnknownTemplate', ...
                    'Unknown plan template "%s".',expectedId);
            end

            template = planWorkflow.templates.TemplateIO.decodeJsonFile( ...
                templateFile);

            planWorkflow.templates.PlanTemplate.validateTemplate( ...
                template,expectedId);
        end

        function template = loadFromFolder(templateFolder,expectedId)
            templateFolder = char(templateFolder);
            expectedId = char(expectedId);
            template = planWorkflow.templates.TemplateIO.loadFromFolder( ...
                templateFolder,expectedId);
        end

        function templateFolder = saveForDescription(template, ...
                description,templateId)
            description = char(description);
            templateId = ...
                planWorkflow.templates.PlanTemplate.normalizeTemplateId( ...
                description,templateId);
            templateFolder = fullfile( ...
                planWorkflow.templates.PlanTemplate.templateRoot(), ...
                description,templateId);
            planWorkflow.templates.PlanTemplate.writeToFolder( ...
                template,templateFolder,description,templateId);
        end

        function writeToFolder(template,templateFolder,description, ...
                templateId)
            templateFolder = char(templateFolder);
            description = char(description);
            templateId = ...
                planWorkflow.templates.PlanTemplate.normalizeTemplateId( ...
                description,templateId);
            planWorkflow.templates.TemplateIO.writeToFolder( ...
                template,templateFolder,description,templateId);
        end

        function components = toComponents(template,description,templateId)
            components = planWorkflow.templates.TemplateIO.toComponents( ...
                template,description,templateId);
        end

        function template = resolve(runConfig,template)
            if nargin < 2
                template = [];
            end
            template = planWorkflow.templates.TemplateResolver.resolve( ...
                runConfig,template);
        end

        function validateRunConfigSelection(runConfig,template)
            if nargin < 2
                template = ...
                    planWorkflow.templates.TemplateResolver.loadForDescription( ...
                    runConfig.description,runConfig.plan_template);
            end

            planWorkflow.templates.TemplateResolver.validateRunConfigSelection( ...
                runConfig,template);
        end

        function beamSet = beamSetById(template,beamSetId)
            beamSet = planWorkflow.templates.TemplateResolver.beamSetById( ...
                template,beamSetId);
        end

        function ids = radiationModeIds(template)
            ids = planWorkflow.templates.TemplateResolver.radiationModeIds( ...
                template);
        end

        function beamSetId = defaultBeamSetForRadiationMode( ...
                template,radiationMode)
            spec = planWorkflow.templates.TemplateResolver.radiationModeSpec( ...
                template,radiationMode);
            beamSetId = char(spec.defaultBeamSet);
        end

        function machine = defaultMachineForRadiationMode( ...
                template,radiationMode)
            spec = planWorkflow.templates.TemplateResolver.radiationModeSpec( ...
                template,radiationMode);
            machine = char(spec.machine);
        end

        function bioModel = defaultBioModelForRadiationMode( ...
                template,radiationMode)
            spec = planWorkflow.templates.TemplateResolver.radiationModeSpec( ...
                template,radiationMode);
            bioModel = char(spec.bioModel);
        end

        function pln = applyBeams(runConfig,pln,ct,cst,template)
            if nargin < 5
                template = [];
            end
            template = planWorkflow.templates.TemplateResolver.resolve( ...
                runConfig,template);
            beamSet = planWorkflow.templates.TemplateResolver.beamSetById( ...
                template,runConfig.plan_beams);
            pln = planWorkflow.templates.BeamApplicator.apply( ...
                runConfig,pln,ct,cst,beamSet);
        end

        function [cst,objectiveInfo] = applyObjectives( ...
                runConfig,~,cst,template,objectiveSetName)
            if nargin < 4
                template = [];
            end
            if nargin < 5 || isempty(objectiveSetName)
                objectiveSetName = 'reference';
            end
            template = planWorkflow.templates.TemplateResolver.resolve( ...
                runConfig,template);
            objectiveSet = planWorkflow.templates.TemplateResolver.objectiveSet( ...
                template,objectiveSetName);
            [cst,objectiveInfo] = ...
                planWorkflow.templates.ObjectiveApplicator.apply( ...
                runConfig,cst,template,objectiveSet,objectiveSetName);
        end

        function [cst,objectiveInfo] = addDerivedStructures( ...
                runConfig,cst,ct,objectiveInfo,template,objectiveSetName)
            if nargin < 5
                template = [];
            end
            if nargin < 6 || isempty(objectiveSetName)
                if isfield(objectiveInfo,'objectiveSetName') && ...
                        ~isempty(objectiveInfo.objectiveSetName)
                    objectiveSetName = objectiveInfo.objectiveSetName;
                else
                    objectiveSetName = 'reference';
                end
            end
            template = planWorkflow.templates.TemplateResolver.resolve( ...
                runConfig,template);
            objectiveSet = planWorkflow.templates.TemplateResolver.objectiveSet( ...
                template,objectiveSetName);
            [cst,objectiveInfo] = ...
                planWorkflow.templates.ObjectiveApplicator.addDerivedStructures( ...
                runConfig,cst,ct,objectiveInfo,template,objectiveSet, ...
                objectiveSetName);
        end

        function validateTemplate(template,expectedId)
            planWorkflow.templates.TemplateValidator.validateTemplate( ...
                template,expectedId);
        end

        function validateEffectiveTemplate(template,runConfig)
            planWorkflow.templates.PlanTemplate.validateTemplate( ...
                template,planWorkflow.templates.PlanTemplate.normalizeTemplateId( ...
                runConfig.description,runConfig.plan_template));
            planWorkflow.templates.PlanTemplate.validateRunConfigSelection( ...
                runConfig,template);
            planWorkflow.templates.TemplateResolver.assertAppliesToRunConfig( ...
                runConfig,template);
            planWorkflow.templates.PlanTemplate.validateDosePullingRunConfig( ...
                template,runConfig);
            robustPlans = ...
                planWorkflow.config.RobustPlanConfig.plansFromRunConfig( ...
                runConfig);
            if ~isempty(robustPlans)
                for planIx = 1:numel(robustPlans)
                    objectiveSet = ...
                        planWorkflow.templates.TemplateResolver.objectiveSet( ...
                        template,robustPlans(planIx).objectiveSetName);
                    planWorkflow.templates.ObjectiveRobustnessContract.forObjectiveSet( ...
                        objectiveSet);
                end
            end
        end

        function validateDosePullingRunConfig(template,runConfig)
            planWorkflow.config.DosePullingConfig.validateActiveStartConfigs( ...
                template,runConfig);
        end

        function hash = hash(template)
            canonicalTemplate = ...
                planWorkflow.templates.PlanTemplate.canonicalize(template);
            text = jsonencode(canonicalTemplate);
            hash = planWorkflow.templates.PlanTemplate.sha256(text);
        end

        function objectiveTypes = supportedObjectiveTypes()
            objectiveTypes = ...
                planWorkflow.templates.ObjectiveFactory.supportedObjectiveTypes();
        end

        function robustnessValues = supportedObjectiveRobustnessValues()
            robustnessValues = ...
                planWorkflow.matRadCapabilitiesReader.supportedObjectiveRobustnessValues();
        end

        function robustnessValues = supportedObjectiveRobustnessValuesForType( ...
                objectiveType)
            robustnessValues = ...
                planWorkflow.matRadCapabilitiesReader.supportedObjectiveRobustnessValuesForType( ...
                objectiveType);
        end

        function validateObjectiveRobustnessForType( ...
                objectiveType,robustness,context)
            if ~planWorkflow.matRadCapabilitiesReader.supportsObjectiveRobustness( ...
                    objectiveType,robustness)
                error('planWorkflow:templates:PlanTemplate:UnsupportedRobustness', ...
                    ['%s.robustness "%s" is not supported by objective ' ...
                    'type "%s".'],context,char(robustness),char(objectiveType));
            end
        end

        function parameterNames = parameterNamesForObjectiveType(objectiveType)
            parameterNames = ...
                planWorkflow.templates.ObjectiveFactory.parameterNamesForObjectiveType( ...
                objectiveType);
        end

        function names = objectiveSetNames(template)
            names = {'reference'};
            if nargin < 1 || isempty(template) || ...
                    ~isfield(template,'objectiveSets') || ...
                    ~isfield(template.objectiveSets,'robustPlans')
                return;
            end
            robustPlans = template.objectiveSets.robustPlans;
            for i = 1:numel(robustPlans)
                names{end + 1} = char(robustPlans(i).id); %#ok<AGROW>
            end
        end

        function labels = objectiveSetLabels(template)
            labels = {'Reference'};
            if nargin < 1 || isempty(template) || ...
                    ~isfield(template,'objectiveSets') || ...
                    ~isfield(template.objectiveSets,'robustPlans')
                return;
            end
            robustPlans = template.objectiveSets.robustPlans;
            for i = 1:numel(robustPlans)
                labels{end + 1} = char(robustPlans(i).label); %#ok<AGROW>
            end
        end

        function robustPlans = robustObjectiveSets(template)
            robustPlans = ...
                planWorkflow.templates.TemplateResolver.robustObjectiveSets( ...
                template);
        end

        function template = setObjectiveSet( ...
                template,objectiveSetName,objectiveSet)
            template = planWorkflow.templates.TemplateMutator.setObjectiveSet( ...
                template,objectiveSetName,objectiveSet);
        end

        function objectiveSet = objectiveSet(template,objectiveSetName)
            objectiveSet = planWorkflow.templates.TemplateResolver.objectiveSet( ...
                template,objectiveSetName);
        end

        function robustPlan = emptyRobustObjectiveSet()
            robustPlan = struct('id','','label','', ...
                'structureObjectives',[], ...
                'ringObjectives',[]);
        end
    end

    methods (Static, Access = private)
        function root = templateRoot()
            root = fullfile(fileparts(mfilename('fullpath')),'json');
        end

        function value = canonicalize(value)
            if isstruct(value)
                for elementIx = 1:numel(value)
                    fields = fieldnames(value(elementIx));
                    for fieldIx = 1:numel(fields)
                        fieldName = fields{fieldIx};
                        value(elementIx).(fieldName) = ...
                            planWorkflow.templates.PlanTemplate.canonicalize( ...
                            value(elementIx).(fieldName));
                    end
                end
                value = orderfields(value);
            elseif iscell(value)
                for i = 1:numel(value)
                    value{i} = planWorkflow.templates.PlanTemplate.canonicalize( ...
                        value{i});
                end
            end
        end

        function hash = sha256(text)
            digest = java.security.MessageDigest.getInstance('SHA-256');
            digest.update(uint8(char(text)));
            bytes = typecast(digest.digest(),'uint8');
            hash = lower(sprintf('%02X',bytes));
        end
    end
end
