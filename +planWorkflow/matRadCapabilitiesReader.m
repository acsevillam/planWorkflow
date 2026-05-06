classdef matRadCapabilitiesReader
    % matRadCapabilitiesReader Reads capabilities from the loaded matRad.

    methods (Static)
        function objectiveTypes = supportedObjectiveTypes()
            classNames = planWorkflow.matRadCapabilitiesReader.optimizationClassNames();
            isObjective = startsWith(classNames,'DoseObjectives.');
            objectiveTypes = cellfun( ...
                @planWorkflow.matRadCapabilitiesReader.localClassName, ...
                classNames(isObjective),'UniformOutput',false);
            objectiveTypes = planWorkflow.matRadCapabilitiesReader.uniqueStable( ...
                objectiveTypes);

            if isempty(objectiveTypes)
                objectiveTypes = {'matRad_SquaredOverdosing', ...
                    'matRad_SquaredDeviation','matRad_MinDVH', ...
                    'matRad_MaxDVH','matRad_MeanDose'};
            end
        end

        function robustnessValues = supportedObjectiveRobustnessValues()
            objectiveTypes = ...
                planWorkflow.matRadCapabilitiesReader.supportedObjectiveTypes();
            robustnessValues = {};
            for i = 1:numel(objectiveTypes)
                robustnessValues = [robustnessValues, ...
                    planWorkflow.matRadCapabilitiesReader.supportedObjectiveRobustnessValuesForType( ...
                    objectiveTypes{i})]; %#ok<AGROW>
            end
            robustnessValues = planWorkflow.matRadCapabilitiesReader.uniqueStable( ...
                robustnessValues);
            if isempty(robustnessValues)
                robustnessValues = {'none'};
            end
        end

        function robustnessValues = supportedObjectiveRobustnessValuesForType( ...
                objectiveType)
            className = ...
                planWorkflow.matRadCapabilitiesReader.objectiveClassName( ...
                objectiveType);
            if isempty(className)
                robustnessValues = {'none'};
                return;
            end

            try
                robustnessValues = eval([className '.availableRobustness()']);
            catch
                robustnessValues = {'none'};
            end
            robustnessValues = cellstr(robustnessValues);
            robustnessValues = planWorkflow.matRadCapabilitiesReader.uniqueStable( ...
                robustnessValues);
        end

        function tf = supportsObjectiveRobustness(objectiveType,robustness)
            robustnessValues = ...
                planWorkflow.matRadCapabilitiesReader.supportedObjectiveRobustnessValuesForType( ...
                objectiveType);
            tf = any(strcmp(char(robustness),robustnessValues));
        end

        function className = objectiveClassName(objectiveType)
            objectiveType = char(objectiveType);
            if startsWith(objectiveType,'DoseObjectives.')
                candidate = objectiveType;
            else
                candidate = ['DoseObjectives.' objectiveType];
            end

            if exist(candidate,'class') == 8
                className = candidate;
            else
                className = '';
            end
        end

        function robustnessModes = supportedWorkflowRobustnessModes()
            baseModes = ...
                planWorkflow.matRadCapabilitiesReader.supportedObjectiveRobustnessValues();
            workflowModes = {'none','STOCH','COWC','c-COWC', ...
                'INTERVAL2','INTERVAL3'};
            if isempty(setdiff(baseModes,{'none'}))
                robustnessModes = workflowModes;
            else
                robustnessModes = ...
                    planWorkflow.matRadCapabilitiesReader.intersectStable( ...
                    workflowModes,baseModes);
            end
            if ~any(strcmp(robustnessModes,'none'))
                robustnessModes = [{'none'},robustnessModes];
            end
        end

        function scenarioModes = supportedScenarioModes()
            scenarioModes = ...
                planWorkflow.matRadCapabilitiesReader.discoverScenarioModes();
            scenarioModes = planWorkflow.matRadCapabilitiesReader.uniqueStable( ...
                scenarioModes);

            if any(strcmp(scenarioModes,'rndScen'))
                scenarioModes{strcmp(scenarioModes,'rndScen')} = 'random';
            end

            if any(strcmp(scenarioModes,'impScen'))
                scenarioModes = [scenarioModes, ...
                    {'impScen5','impScen7','impScen_permuted5', ...
                    'impScen_permuted7'}]; %#ok<AGROW>
            end
            if any(strcmp(scenarioModes,'truncatedImpScen'))
                scenarioModes = [scenarioModes, ...
                    {'impScen_permuted5_truncated', ...
                    'impScen_permuted7_truncated'}]; %#ok<AGROW>
                scenarioModes(strcmp(scenarioModes,'truncatedImpScen')) = [];
            end

            scenarioModes = planWorkflow.matRadCapabilitiesReader.uniqueStable( ...
                scenarioModes);
            if isempty(scenarioModes)
                scenarioModes = {'nomScen','wcScen','impScen','impScen5', ...
                    'impScen7','impScen_permuted5','impScen_permuted7', ...
                    'impScen_permuted5_truncated', ...
                    'impScen_permuted7_truncated','random'};
            end
        end

        function optimizers = supportedOptimizers()
            optimizerSpecs = { ...
                'IPOPT','matRad_OptimizerIPOPT'; ...
                'fmincon','matRad_OptimizerFmincon'; ...
                'simulannealbnd','matRad_OptimizerSimulannealbnd'};
            optimizers = {};
            for i = 1:size(optimizerSpecs,1)
                if exist(optimizerSpecs{i,2},'class') == 8 || ...
                        exist(optimizerSpecs{i,2},'file') == 2
                    optimizers{end + 1} = optimizerSpecs{i,1}; %#ok<AGROW>
                end
            end
            if isempty(optimizers)
                optimizers = optimizerSpecs(:,1)';
            end
        end

        function radiationModes = supportedRadiationModes()
            radiationModes = {};
            if exist('matRad_getAvailableMachines','file') == 2
                try
                    machines = matRad_getAvailableMachines();
                    radiationModes = ...
                        planWorkflow.matRadCapabilitiesReader.radiationModesFromMachines( ...
                        machines);
                catch
                    radiationModes = {};
                end
            end
            radiationModes = planWorkflow.matRadCapabilitiesReader.uniqueStable( ...
                radiationModes);
            if isempty(radiationModes)
                radiationModes = ...
                    planWorkflow.matRadCapabilitiesReader.defaultExternalRadiationModes();
            end
            radiationModes = ...
                planWorkflow.matRadCapabilitiesReader.orderRadiationModes( ...
                radiationModes);
        end

        function acquisitionTypes = supportedAcquisitionTypes()
            acquisitionTypes = {'dicom','mat'};
        end

        function machines = supportedMachines(radiationMode)
            radiationMode = char(radiationMode);
            machines = {};
            if exist('matRad_getAvailableMachines','file') == 2
                try
                    machineMap = matRad_getAvailableMachines(radiationMode);
                    machines = ...
                        planWorkflow.matRadCapabilitiesReader.machineNamesForMode( ...
                        machineMap,radiationMode);
                catch
                    machines = {};
                end
            end
            machines = planWorkflow.matRadCapabilitiesReader.uniqueStable( ...
                machines);
            if isempty(machines)
                machines = {'Generic'};
            end
        end

        function bioModels = supportedBioModels(radiationMode)
            specs = ...
                planWorkflow.matRadCapabilitiesReader.supportedBioModelSpecs( ...
                radiationMode);
            bioModels = {specs.name};
        end

        function specs = supportedBioModelSpecs(radiationMode)
            names = ...
                planWorkflow.matRadCapabilitiesReader.supportedBioModelNames( ...
                radiationMode);
            quantities = cell(1,numel(names));
            for modelIx = 1:numel(names)
                quantities{modelIx} = ...
                    planWorkflow.matRadCapabilitiesReader.defaultQuantityForBioModel( ...
                    radiationMode,names{modelIx});
            end
            specs = planWorkflow.matRadCapabilitiesReader.bioModelSpecs( ...
                names,quantities);
        end

        function bioModel = defaultBioModel(radiationMode)
            bioModels = ...
                planWorkflow.matRadCapabilitiesReader.supportedBioModels( ...
                radiationMode);
            bioModel = bioModels{1};
        end

        function quantity = doseQuantityForBioModel(radiationMode,bioModel)
            specs = ...
                planWorkflow.matRadCapabilitiesReader.supportedBioModelSpecs( ...
                radiationMode);
            names = {specs.name};
            matchIx = find(strcmp(char(bioModel),names),1);
            if isempty(matchIx)
                error(['planWorkflow:matRadCapabilitiesReader:' ...
                    'UnsupportedBioModel'], ...
                    ['Biological model "%s" is not supported for ' ...
                     'radiationMode "%s".'],char(bioModel), ...
                    char(radiationMode));
            end
            quantity = specs(matchIx).quantityOpt;
        end

        function quantities = supportedDoseQuantities(radiationMode,bioModel)
            quantities = ...
                planWorkflow.matRadCapabilitiesReader.supportedDoseQuantitiesForBioModel( ...
                radiationMode,bioModel);
            if isempty(quantities)
                error(['planWorkflow:matRadCapabilitiesReader:' ...
                    'UnsupportedDoseQuantitySelection'], ...
                    ['No supported dose quantities were found for ' ...
                     'radiationMode "%s" and bioModel "%s".'], ...
                    char(radiationMode),char(bioModel));
            end
        end

        function quantities = supportedDoseQuantityNames()
            quantities = ...
                planWorkflow.matRadCapabilitiesReader.doseQuantityCandidates();
        end
    end

    methods (Static, Access = private)
        function names = supportedBioModelNames(radiationMode)
            candidates = ...
                planWorkflow.matRadCapabilitiesReader.bioModelCandidates();
            names = {};
            if exist('matRad_bioModel','file') == 2
                for modelIx = 1:numel(candidates)
                    quantities = ...
                        planWorkflow.matRadCapabilitiesReader.supportedDoseQuantitiesForBioModel( ...
                        radiationMode,candidates{modelIx});
                    if ~isempty(quantities)
                        names{end + 1} = candidates{modelIx}; %#ok<AGROW>
                    end
                end
            end
            if isempty(names)
                names = candidates;
            end
            names = ...
                planWorkflow.matRadCapabilitiesReader.orderBioModels( ...
                radiationMode,names);
        end

        function names = bioModelCandidates()
            names = ...
                planWorkflow.matRadCapabilitiesReader.biologicalModelConstant( ...
                'availableModels');
            if isempty(names)
                names = {'none'};
            end
            names = planWorkflow.matRadCapabilitiesReader.uniqueStable(names);
        end

        function quantities = doseQuantityCandidates()
            quantities = ...
                planWorkflow.matRadCapabilitiesReader.biologicalModelConstant( ...
                'availableQuantitiesForOpt');
            if isempty(quantities)
                quantities = {'physicalDose'};
            end
            quantities = planWorkflow.matRadCapabilitiesReader.uniqueStable( ...
                quantities);
        end

        function values = biologicalModelConstant(propertyName)
            values = {};
            if exist('matRad_BiologicalModel','class') ~= 8
                return;
            end
            try
                values = eval(['matRad_BiologicalModel.' char(propertyName)]);
            catch
                values = {};
            end
            if ischar(values) || isstring(values)
                values = cellstr(values);
            end
        end

        function names = orderBioModels(radiationMode,names)
            preference = ...
                planWorkflow.matRadCapabilitiesReader.bioModelPreference( ...
                radiationMode);
            ordered = {};
            for preferenceIx = 1:numel(preference)
                matchIx = strcmp(names,preference{preferenceIx});
                if any(matchIx)
                    ordered{end + 1} = preference{preferenceIx}; %#ok<AGROW>
                end
            end
            names = [ordered,names(~ismember(names,ordered))];
        end

        function preference = bioModelPreference(radiationMode)
            switch char(radiationMode)
                case {'photons','brachy'}
                    preference = {'none','constRBE'};
                case 'protons'
                    preference = {'constRBE','MCN','WED','none'};
                case 'helium'
                    preference = {'HEL','LEM','none'};
                case 'carbon'
                    preference = {'LEM','none'};
                otherwise
                    preference = {'none'};
            end
        end

        function quantity = defaultQuantityForBioModel(radiationMode,bioModel)
            quantities = ...
                planWorkflow.matRadCapabilitiesReader.supportedDoseQuantitiesForBioModel( ...
                radiationMode,bioModel);
            if isempty(quantities)
                quantity = ...
                    planWorkflow.matRadCapabilitiesReader.fallbackQuantityForBioModel( ...
                    bioModel);
                return;
            end
            if strcmp(char(bioModel),'none') && ...
                    any(strcmp(quantities,'physicalDose'))
                quantity = 'physicalDose';
                return;
            end
            if any(strcmp(quantities,'RBExD'))
                quantity = 'RBExD';
                return;
            end
            quantity = quantities{1};
        end

        function quantities = supportedDoseQuantitiesForBioModel( ...
                radiationMode,bioModel)
            quantities = {};
            if exist('matRad_bioModel','file') ~= 2
                return;
            end
            candidates = ...
                planWorkflow.matRadCapabilitiesReader.doseQuantityCandidates();
            for quantityIx = 1:numel(candidates)
                quantity = candidates{quantityIx};
                if planWorkflow.matRadCapabilitiesReader.bioModelAcceptsQuantity( ...
                        radiationMode,bioModel,quantity)
                    quantities{end + 1} = quantity; %#ok<AGROW>
                end
            end
            quantities = planWorkflow.matRadCapabilitiesReader.uniqueStable( ...
                quantities);
        end

        function tf = bioModelAcceptsQuantity(radiationMode,bioModel, ...
                quantity)
            tf = false;
            try
                warningState = warning('off','matRad:Warning');
                cleanup = onCleanup(@() warning(warningState));
                model = [];
                evalc('model = matRad_bioModel(char(radiationMode),char(quantity),char(bioModel));');
            catch
                return;
            end
            if isempty(model)
                return;
            end
            modelName = ...
                planWorkflow.matRadCapabilitiesReader.bioModelProperty( ...
                model,'model');
            quantityOpt = ...
                planWorkflow.matRadCapabilitiesReader.bioModelProperty( ...
                model,'quantityOpt');
            tf = strcmp(modelName,char(bioModel)) && ...
                strcmp(quantityOpt,char(quantity));
        end

        function value = bioModelProperty(model,fieldName)
            value = '';
            try
                value = char(model.(fieldName));
            catch
                value = '';
            end
        end

        function quantity = fallbackQuantityForBioModel(bioModel)
            if strcmp(char(bioModel),'none')
                quantity = 'physicalDose';
            else
                quantity = 'RBExD';
            end
        end

        function specs = bioModelSpecs(names,quantities)
            specs = repmat(struct('name','','quantityOpt',''),1,numel(names));
            for specIx = 1:numel(names)
                specs(specIx).name = char(names{specIx});
                specs(specIx).quantityOpt = char(quantities{specIx});
            end
        end

        function classNames = optimizationClassNames()
            if exist('matRad_getObjectivesAndConstraints','file') ~= 2
                classNames = {};
                return;
            end

            try
                discovered = matRad_getObjectivesAndConstraints();
            catch
                classNames = {};
                return;
            end

            if isempty(discovered)
                classNames = {};
            elseif iscell(discovered)
                classNames = discovered(1,:);
            else
                classNames = cellstr(discovered(1,:));
            end
        end

        function scenarioModes = discoverScenarioModes()
            scenarioClasses = { ...
                'matRad_NominalScenario','nomScen'; ...
                'matRad_WorstCaseScenarios','wcScen'; ...
                'matRad_ImportanceScenarios','impScen'; ...
                'matRad_TruncatedImportanceScenarios','truncatedImpScen'; ...
                'matRad_RandomScenarios','rndScen'};
            scenarioModes = {};

            for i = 1:size(scenarioClasses,1)
                className = scenarioClasses{i,1};
                if exist(className,'class') ~= 8
                    continue;
                end

                scenarioMode = ...
                    planWorkflow.matRadCapabilitiesReader.classPropertyDefault( ...
                    className,'name');
                if isempty(scenarioMode)
                    scenarioMode = scenarioClasses{i,2};
                end
                scenarioModes{end + 1} = scenarioMode; %#ok<AGROW>
            end
        end

        function radiationModes = radiationModesFromMachines(machines)
            radiationModes = {};

            if isa(machines,'containers.Map')
                machineModes = keys(machines);
                for i = 1:numel(machineModes)
                    machineNames = machines(machineModes{i});
                    if ~isempty(machineNames)
                        radiationModes{end + 1} = machineModes{i}; %#ok<AGROW>
                    end
                end
                return;
            end

            if isstruct(machines) && isfield(machines,'radiationMode')
                radiationModes = {machines.radiationMode};
                return;
            end

            if iscellstr(machines)
                radiationModes = machines;
            end
        end

        function machineNames = machineNamesForMode(machines,radiationMode)
            machineNames = {};
            if isa(machines,'containers.Map')
                if isKey(machines,radiationMode)
                    machineNames = machines(radiationMode);
                end
                return;
            end

            if isstruct(machines)
                if isfield(machines,'radiationMode') && ...
                        isfield(machines,'machine')
                    ix = strcmp({machines.radiationMode},radiationMode);
                    machineNames = {machines(ix).machine};
                elseif isfield(machines,'name')
                    machineNames = {machines.name};
                end
                return;
            end

            if iscellstr(machines)
                machineNames = machines;
            end
        end

        function radiationModes = defaultExternalRadiationModes()
            radiationModes = {'photons','protons','helium','carbon'};
        end

        function radiationModes = orderRadiationModes(radiationModes)
            preferredModes = ...
                planWorkflow.matRadCapabilitiesReader.defaultExternalRadiationModes();
            orderedModes = planWorkflow.matRadCapabilitiesReader.intersectStable( ...
                preferredModes,radiationModes);
            extraModes = radiationModes( ...
                ~cellfun(@(mode) any(strcmp(mode,preferredModes)), ...
                radiationModes));
            radiationModes = [orderedModes extraModes];
        end

        function value = classPropertyDefault(className,propertyName)
            value = '';
            try
                metaClass = meta.class.fromName(className);
                if isempty(metaClass)
                    return;
                end
                propertyList = metaClass.PropertyList;
                propertyIx = arrayfun( ...
                    @(property) strcmp(property.Name,propertyName), ...
                    propertyList);
                if ~any(propertyIx)
                    return;
                end
                value = propertyList(propertyIx).DefaultValue;
            catch
                value = '';
            end
        end

        function localName = localClassName(className)
            parts = strsplit(char(className),'.');
            localName = parts{end};
        end

        function values = intersectStable(left,right)
            values = {};
            for i = 1:numel(left)
                if any(strcmp(left{i},right))
                    values{end + 1} = left{i}; %#ok<AGROW>
                end
            end
        end

        function values = uniqueStable(values)
            values = cellstr(values);
            values = values(~cellfun(@isempty,values));
            [~,ix] = unique(values,'stable');
            values = values(sort(ix));
        end
    end
end
