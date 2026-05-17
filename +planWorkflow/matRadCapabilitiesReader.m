classdef matRadCapabilitiesReader
    % matRadCapabilitiesReader Reads capabilities from the loaded matRad.

    methods (Static)
        function objectiveTypes = supportedObjectiveTypes()
            persistent cachedObjectiveTypes cachedContextKey
            contextKey = ...
                planWorkflow.matRadCapabilitiesReader.capabilitiesCacheKey();
            if ~isempty(cachedObjectiveTypes) && ...
                    isequal(cachedContextKey,contextKey)
                objectiveTypes = cachedObjectiveTypes;
                return;
            end

            classNames = planWorkflow.matRadCapabilitiesReader.optimizationClassNames();
            isOptimizationFunction = startsWith(classNames,'DoseObjectives.') | ...
                startsWith(classNames,'DoseConstraints.');
            objectiveTypes = cellfun( ...
                @planWorkflow.matRadCapabilitiesReader.localClassName, ...
                classNames(isOptimizationFunction),'UniformOutput',false);
            objectiveTypes = planWorkflow.matRadCapabilitiesReader.uniqueStable( ...
                objectiveTypes);

            if isempty(objectiveTypes)
                objectiveTypes = {'matRad_SquaredOverdosing', ...
                    'matRad_SquaredDeviation','matRad_MinDVH', ...
                    'matRad_MaxDVH','matRad_MeanDose'};
            end
            cachedObjectiveTypes = objectiveTypes;
            cachedContextKey = contextKey;
        end

        function robustnessValues = supportedObjectiveRobustnessValues()
            persistent cachedRobustnessValues cachedContextKey
            contextKey = ...
                planWorkflow.matRadCapabilitiesReader.capabilitiesCacheKey();
            if ~isempty(cachedRobustnessValues) && ...
                    isequal(cachedContextKey,contextKey)
                robustnessValues = cachedRobustnessValues;
                return;
            end

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
            cachedRobustnessValues = robustnessValues;
            cachedContextKey = contextKey;
        end

        function robustnessValues = supportedObjectiveRobustnessValuesForType( ...
                objectiveType)
            persistent cache
            if isempty(cache)
                cache = containers.Map('KeyType','char','ValueType','any');
            end
            cacheKey = sprintf('%s|%s', ...
                planWorkflow.matRadCapabilitiesReader.capabilitiesCacheKey(), ...
                char(objectiveType));
            if isKey(cache,cacheKey)
                robustnessValues = cache(cacheKey);
                return;
            end

            className = ...
                planWorkflow.matRadCapabilitiesReader.objectiveClassName( ...
                objectiveType);
            if isempty(className)
                robustnessValues = {'none'};
                cache(cacheKey) = robustnessValues;
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
            cache(cacheKey) = robustnessValues;
        end

        function tf = supportsObjectiveRobustness(objectiveType,robustness)
            robustnessValues = ...
                planWorkflow.matRadCapabilitiesReader.supportedObjectiveRobustnessValuesForType( ...
                objectiveType);
            tf = any(strcmp(char(robustness),robustnessValues));
        end

        function className = objectiveClassName(objectiveType)
            objectiveType = char(objectiveType);
            if startsWith(objectiveType,'DoseObjectives.') || ...
                    startsWith(objectiveType,'DoseConstraints.')
                candidate = objectiveType;
            else
                candidate = ['DoseObjectives.' objectiveType];
            end

            if exist(candidate,'class') == 8
                className = candidate;
                return;
            end

            candidate = ['DoseConstraints.' objectiveType];
            if exist(candidate,'class') == 8
                className = candidate;
            else
                className = '';
            end
        end

        function robustnessModes = supportedWorkflowRobustnessModes()
            persistent cachedModes cachedContextKey
            contextKey = ...
                planWorkflow.matRadCapabilitiesReader.capabilitiesCacheKey();
            if ~isempty(cachedModes) && isequal(cachedContextKey,contextKey)
                robustnessModes = cachedModes;
                return;
            end

            baseModes = ...
                planWorkflow.matRadCapabilitiesReader.supportedObjectiveRobustnessValues();
            workflowModes = {'none','STOCH','COWC','c-COWC', ...
                'PROB2','INTERVAL2','INTERVAL3'};
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
            cachedModes = robustnessModes;
            cachedContextKey = contextKey;
        end

        function scenarioModes = supportedScenarioModes()
            persistent cachedModes cachedContextKey
            contextKey = ...
                planWorkflow.matRadCapabilitiesReader.capabilitiesCacheKey();
            if ~isempty(cachedModes) && isequal(cachedContextKey,contextKey)
                scenarioModes = cachedModes;
                return;
            end

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
                    'impScen_permuted7_truncated','random', ...
                    'truncatedRndScen'};
            end
            cachedModes = scenarioModes;
            cachedContextKey = contextKey;
        end

        function optimizers = supportedOptimizers()
            persistent cachedOptimizers cachedContextKey
            contextKey = ...
                planWorkflow.matRadCapabilitiesReader.capabilitiesCacheKey();
            if ~isempty(cachedOptimizers) && ...
                    isequal(cachedContextKey,contextKey)
                optimizers = cachedOptimizers;
                return;
            end

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
            cachedOptimizers = optimizers;
            cachedContextKey = contextKey;
        end

        function radiationModes = supportedRadiationModes()
            persistent cachedModes cachedContextKey
            contextKey = ...
                planWorkflow.matRadCapabilitiesReader.capabilitiesCacheKey();
            if ~isempty(cachedModes) && isequal(cachedContextKey,contextKey)
                radiationModes = cachedModes;
                return;
            end

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
            cachedModes = radiationModes;
            cachedContextKey = contextKey;
        end

        function acquisitionTypes = supportedAcquisitionTypes()
            acquisitionTypes = {'dicom','mat'};
        end

        function machines = supportedMachines(radiationMode)
            persistent cache
            if isempty(cache)
                cache = containers.Map('KeyType','char','ValueType','any');
            end
            radiationMode = char(radiationMode);
            cacheKey = sprintf('%s|%s', ...
                planWorkflow.matRadCapabilitiesReader.capabilitiesCacheKey(), ...
                radiationMode);
            if isKey(cache,cacheKey)
                machines = cache(cacheKey);
                return;
            end

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
            cache(cacheKey) = machines;
        end

        function bioModels = supportedBioModels(radiationMode)
            specs = ...
                planWorkflow.matRadCapabilitiesReader.supportedBioModelSpecs( ...
                radiationMode);
            bioModels = {specs.name};
        end

        function specs = supportedBioModelSpecs(radiationMode)
            persistent cache
            if isempty(cache)
                cache = containers.Map('KeyType','char','ValueType','any');
            end
            cacheKey = sprintf('%s|%s', ...
                planWorkflow.matRadCapabilitiesReader.capabilitiesCacheKey(), ...
                char(radiationMode));
            if isKey(cache,cacheKey)
                specs = cache(cacheKey);
                return;
            end

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
            cache(cacheKey) = specs;
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
            persistent cache
            if isempty(cache)
                cache = containers.Map('KeyType','char','ValueType','any');
            end
            cacheKey = sprintf('%s|%s|%s', ...
                planWorkflow.matRadCapabilitiesReader.capabilitiesCacheKey(), ...
                char(radiationMode), ...
                char(bioModel));
            if isKey(cache,cacheKey)
                quantities = cache(cacheKey);
                return;
            end

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
            cache(cacheKey) = quantities;
        end

        function quantities = supportedDoseQuantityNames()
            persistent cachedQuantities cachedContextKey
            contextKey = ...
                planWorkflow.matRadCapabilitiesReader.capabilitiesCacheKey();
            if ~isempty(cachedQuantities) && ...
                    isequal(cachedContextKey,contextKey)
                quantities = cachedQuantities;
                return;
            end
            quantities = ...
                planWorkflow.matRadCapabilitiesReader.doseQuantityCandidates();
            cachedQuantities = quantities;
            cachedContextKey = contextKey;
        end
    end

    methods (Static, Access = private)
        function names = supportedBioModelNames(radiationMode)
            names = {};
            if exist('matRad_BiologicalModel','class') == 8
                try
                    classList = matRad_BiologicalModel.getAvailableModels( ...
                        char(radiationMode), ...
                        planWorkflow.matRadCapabilitiesReader.bioModelInputQuantities());
                    names = {classList.model};
                catch
                    names = {};
                end
            end
            if isempty(names)
                names = ...
                    planWorkflow.matRadCapabilitiesReader.bioModelCandidates();
            end
            names = ...
                planWorkflow.matRadCapabilitiesReader.orderBioModels( ...
                radiationMode,names);
        end

        function names = bioModelCandidates()
            names = {};
            if exist('matRad_BiologicalModel','class') == 8
                try
                    classList = matRad_BiologicalModel.getAvailableModels();
                    names = {classList.model};
                catch
                    names = {};
                end
            end
            if isempty(names)
                names = {'none','constRBE','MCN','WED','HEL','LEM'};
            end
            names = planWorkflow.matRadCapabilitiesReader.uniqueStable(names);
        end

        function quantities = doseQuantityCandidates()
            quantities = ...
                planWorkflow.matRadCapabilitiesReader.biologicalModelConstant( ...
                'availableQuantitiesForOpt');
            if isempty(quantities)
                quantities = {'physicalDose','RBExD','effect','BED'};
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
            if strcmp(char(bioModel),'none')
                if any(strcmp(char(radiationMode),{'photons','brachy'}))
                    quantities = {'physicalDose','RBExD','effect','BED'};
                else
                    quantities = {'physicalDose'};
                end
                return;
            end

            defaultQuantity = ...
                planWorkflow.matRadCapabilitiesReader.defaultReportQuantityForBioModel( ...
                bioModel);
            if isempty(defaultQuantity)
                defaultQuantity = ...
                    planWorkflow.matRadCapabilitiesReader.fallbackQuantityForBioModel( ...
                    bioModel);
            end
            quantities = {defaultQuantity};
            if planWorkflow.matRadCapabilitiesReader.bioModelSupportsEffectQuantities( ...
                    bioModel)
                quantities = [quantities,{'effect','BED'}]; %#ok<AGROW>
            end
            quantities = planWorkflow.matRadCapabilitiesReader.uniqueStable( ...
                quantities);
        end

        function quantity = fallbackQuantityForBioModel(bioModel)
            if strcmp(char(bioModel),'none')
                quantity = 'physicalDose';
            else
                quantity = 'RBExD';
            end
        end

        function quantities = bioModelInputQuantities()
            quantities = {'physicalDose','LET','alpha','beta','spectra'};
        end

        function quantity = defaultReportQuantityForBioModel(bioModel)
            quantity = '';
            if exist('matRad_BiologicalModel','class') ~= 8
                return;
            end
            try
                classList = matRad_BiologicalModel.getAvailableModels();
            catch
                return;
            end
            modelIx = find(strcmp({classList.model},char(bioModel)),1);
            if isempty(modelIx)
                return;
            end
            try
                model = classList(modelIx).handle();
                quantity = ...
                    planWorkflow.matRadCapabilitiesReader.toWorkflowQuantity( ...
                    model.defaultReportQuantity);
            catch
                quantity = '';
            end
        end

        function tf = bioModelSupportsEffectQuantities(bioModel)
            tf = any(strcmp(char(bioModel), ...
                {'CAR','LSM','MCN','WED','TAB','LEM','HEL'}));
        end

        function quantity = toWorkflowQuantity(quantity)
            quantity = char(quantity);
            if strcmp(quantity,'RBExDose')
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
                'matRad_RandomScenarios','rndScen'; ...
                'matRad_TruncatedRandomScenarios','truncatedRndScen'};
            scenarioModes = {};

            for i = 1:size(scenarioClasses,1)
                className = scenarioClasses{i,1};
                if exist(className,'class') ~= 8
                    continue;
                end

                scenarioModes{end + 1} = scenarioClasses{i,2}; %#ok<AGROW>
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

        function cacheKey = capabilitiesCacheKey()
            persistent cachedKey cachedPath
            currentPath = path;
            if ~isempty(cachedKey) && isequal(cachedPath,currentPath)
                cacheKey = cachedKey;
                return;
            end

            components = { ...
                which('matRad_rc'), ...
                which('matRad_getAvailableMachines'), ...
                which('matRad_getObjectivesAndConstraints'), ...
                which('matRad_bioModel'), ...
                which('matRad_BiologicalModel'), ...
                which('matRad_NominalScenario'), ...
                which('matRad_OptimizerIPOPT')};
            cacheKey = strjoin(components,'|');
            cachedKey = cacheKey;
            cachedPath = currentPath;
        end
    end
end
