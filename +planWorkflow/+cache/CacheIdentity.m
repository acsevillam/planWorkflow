classdef CacheIdentity
    % CacheIdentity Builds canonical identities for workflow cache artifacts.

    methods (Static)
        function descriptor = build(runConfig,tag,pln,context)
            if nargin < 3
                pln = struct();
            end
            if nargin < 4 || isempty(context)
                context = struct();
            end

            tag = char(tag);
            artifact = planWorkflow.cache.CacheIdentity.artifactFromTag(tag);
            artifact = planWorkflow.cache.CacheIdentity.enrichArtifact( ...
                runConfig,artifact);
            identity = planWorkflow.cache.CacheIdentity.identityStruct( ...
                runConfig,tag,artifact,pln,context);
            canonicalIdentity = ...
                planWorkflow.cache.CacheIdentity.canonicalize(identity);
            identityText = jsonencode(canonicalIdentity);
            identityHash = planWorkflow.cache.CacheIdentity.sha256( ...
                identityText);
            shortHash = identityHash(1:16);

            descriptor = struct();
            descriptor.tag = tag;
            descriptor.artifact = artifact;
            descriptor.identity = canonicalIdentity;
            descriptor.identityHash = identityHash;
            descriptor.shortHash = shortHash;
            descriptor.relativeKey = ...
                planWorkflow.cache.CacheIdentity.relativeKey( ...
                runConfig,artifact,canonicalIdentity,shortHash);
        end

        function identity = cstIdentity(cst)
            identity = struct('structures',[]);
            if ~iscell(cst) || isempty(cst)
                return;
            end

            structures = repmat(struct( ...
                'name','','role','','priority',[], ...
                'tissueClass',[],'alphaX',[],'betaX',[], ...
                'voxelHash',''),0,1);
            for i = 1:size(cst,1)
                item = struct();
                item.name = planWorkflow.cache.CacheIdentity.cellText( ...
                    cst,i,2);
                item.role = planWorkflow.cache.CacheIdentity.cellText( ...
                    cst,i,3);
                item.priority = ...
                    planWorkflow.cache.CacheIdentity.structureProperty( ...
                    cst,i,'Priority');
                item.tissueClass = ...
                    planWorkflow.cache.CacheIdentity.structureProperty( ...
                    cst,i,'TissueClass');
                item.alphaX = ...
                    planWorkflow.cache.CacheIdentity.structureProperty( ...
                    cst,i,'alphaX');
                item.betaX = ...
                    planWorkflow.cache.CacheIdentity.structureProperty( ...
                    cst,i,'betaX');
                if size(cst,2) >= 4
                    item.voxelHash = ...
                        planWorkflow.cache.CacheIdentity.valueHash(cst{i,4});
                else
                    item.voxelHash = '';
                end
                structures(end + 1,1) = item; %#ok<AGROW>
            end
            identity.structures = structures;
        end

        function hash = valueHash(value)
            canonicalValue = ...
                planWorkflow.cache.CacheIdentity.canonicalize(value);
            hash = planWorkflow.cache.CacheIdentity.sha256( ...
                jsonencode(canonicalValue));
        end

        function fingerprint = scenarioFingerprint(multScen)
            identity = ...
                planWorkflow.cache.CacheIdentity.scenarioModelIdentity( ...
                multScen);
            fingerprint = planWorkflow.cache.CacheIdentity.valueHash(identity);
        end

        function metadata = artifactMetadata(runConfig,tag)
            artifact = planWorkflow.cache.CacheIdentity.artifactFromTag( ...
                char(tag));
            artifact = planWorkflow.cache.CacheIdentity.enrichArtifact( ...
                runConfig,artifact);
            metadata = struct();
            metadata.kind = artifact.kind;
            metadata.planId = artifact.planId;
            metadata.variantId = artifact.variantId;
            metadata.robustnessMode = artifact.robustnessMode;
            if isfield(artifact,'role') && ~isempty(artifact.role)
                metadata.role = artifact.role;
            end
            if any(strcmp(artifact.kind,{'robust','interval','prob'}))
                plan = planWorkflow.cache.CacheIdentity.robustPlanForArtifact( ...
                    runConfig,artifact);
                planMetadata = ...
                    planWorkflow.cache.CacheIdentity.robustPlanMetadata(plan);
                fields = fieldnames(planMetadata);
                for fieldIx = 1:numel(fields)
                    metadata.(fields{fieldIx}) = ...
                        planMetadata.(fields{fieldIx});
                end
            end
        end
    end

    methods (Static, Access = private)
        function artifact = artifactFromTag(tag)
            artifact = struct('kind','other','planId','', ...
                'variantId','','robustnessMode','','role','');
            if strcmp(tag,'reference')
                artifact.kind = 'reference';
            elseif startsWith(tag,'robustNominal_')
                artifact.kind = 'robust';
                artifact.planId = char(extractAfter(tag,'robustNominal_'));
                artifact.role = 'nominal';
            elseif startsWith(tag,'robust_')
                artifact.kind = 'robust';
                artifact.planId = char(extractAfter(tag,'robust_'));
            elseif startsWith(tag,'interval_')
                artifact.kind = 'interval';
                artifact.planId = char(extractAfter(tag,'interval_'));
            elseif startsWith(tag,'prob_')
                artifact.kind = 'prob';
                artifact.planId = char(extractAfter(tag,'prob_'));
            end
            artifact.planId = char(artifact.planId);
            artifact.variantId = char(artifact.variantId);
            artifact.robustnessMode = char(artifact.robustnessMode);
            artifact.role = char(artifact.role);
        end

        function artifact = enrichArtifact(runConfig,artifact)
            if ~any(strcmp(artifact.kind,{'robust','interval','prob'}))
                return;
            end
            plan = planWorkflow.cache.CacheIdentity.robustPlanForArtifact( ...
                runConfig,artifact);
            artifact.robustnessMode = char(plan.robustnessMode);
        end

        function identity = identityStruct(runConfig,~,artifact,pln,context)
            identity = struct();
            identity.schemaVersion = 1;
            identity.tag = ...
                planWorkflow.cache.CacheIdentity.physicalTag(artifact);
            identity.artifact = ...
                planWorkflow.cache.CacheIdentity.physicalArtifact(artifact);
            identity.patient = ...
                planWorkflow.cache.CacheIdentity.patientIdentity(runConfig);
            identity.modality = ...
                planWorkflow.cache.CacheIdentity.modalityIdentity( ...
                runConfig,pln);
            identity.doseCalculation = ...
                planWorkflow.cache.CacheIdentity.doseCalculationIdentity( ...
                runConfig,pln);
            identity.optimization = ...
                planWorkflow.cache.CacheIdentity.optimizationIdentity(pln);
            identity.beam = ...
                planWorkflow.cache.CacheIdentity.beamIdentity(runConfig,pln);
            identity.scenario = ...
                planWorkflow.cache.CacheIdentity.scenarioIdentity( ...
                runConfig,pln,artifact);
            if isfield(context,'cst')
                identity.cst = ...
                    planWorkflow.cache.CacheIdentity.cstIdentity( ...
                    context.cst);
            end
            if strcmp(artifact.kind,'interval')
                identity.interval = ...
                    planWorkflow.cache.CacheIdentity.intervalIdentity( ...
                    context);
            end
            if strcmp(artifact.kind,'prob')
                identity.prob = ...
                    planWorkflow.cache.CacheIdentity.probIdentity(context);
            end
            if isfield(context,'stf')
                identity.stf = context.stf;
            end
        end

        function identity = patientIdentity(runConfig)
            identity = struct();
            identity.description = ...
                planWorkflow.cache.CacheIdentity.configText( ...
                runConfig,'description');
            identity.caseID = ...
                planWorkflow.cache.CacheIdentity.configText( ...
                runConfig,'caseID');
            identity.AcquisitionType = ...
                planWorkflow.cache.CacheIdentity.configText( ...
                runConfig,'AcquisitionType');
            identity.dicomMetadata = ...
                planWorkflow.cache.CacheIdentity.configValue( ...
                runConfig,'dicomMetadata',struct());
        end

        function identity = modalityIdentity(runConfig,pln)
            identity = struct();
            identity.radiationMode = ...
                planWorkflow.cache.CacheIdentity.configText( ...
                runConfig,'radiationMode');
            identity.machine = ...
                planWorkflow.cache.CacheIdentity.configText( ...
                runConfig,'machine');
            identity.bioModel = ...
                planWorkflow.cache.CacheIdentity.configText( ...
                runConfig,'bioModel');
            if isstruct(pln) && isfield(pln,'radiationMode')
                identity.radiationMode = char(pln.radiationMode);
            end
            if isstruct(pln) && isfield(pln,'machine')
                identity.machine = char(pln.machine);
            end
            if isstruct(pln) && isfield(pln,'bioParam')
                identity.quantityOpt = ...
                    planWorkflow.cache.CacheIdentity.bioParamField( ...
                    pln.bioParam,'quantityOpt');
                identity.bioModel = ...
                    planWorkflow.cache.CacheIdentity.bioParamField( ...
                    pln.bioParam,'model',identity.bioModel);
            else
                identity.quantityOpt = '';
            end
        end

        function identity = doseCalculationIdentity(runConfig,pln)
            identity = struct();
            identity.hlutFileName = ...
                planWorkflow.cache.CacheIdentity.configText( ...
                runConfig,'hlutFileName');
            identity.doseResolution = ...
                planWorkflow.cache.CacheIdentity.configValue( ...
                runConfig,'doseResolution',[]);
            identity.engine = ...
                planWorkflow.cache.CacheIdentity.nestedField( ...
                pln,{'propDoseCalc','engine'},'');
            identity.calcLET = ...
                planWorkflow.cache.CacheIdentity.nestedField( ...
                pln,{'propDoseCalc','calcLET'},[]);
            identity.doseGridResolution = ...
                planWorkflow.cache.CacheIdentity.doseGridResolution(pln);
        end

        function identity = optimizationIdentity(pln)
            identity = struct();
            identity.scen4D = ...
                planWorkflow.cache.CacheIdentity.nestedField( ...
                pln,{'propOpt','scen4D'},[]);
        end

        function identity = beamIdentity(runConfig,pln)
            identity = struct();
            identity.plan_beams = ...
                planWorkflow.cache.CacheIdentity.configText( ...
                runConfig,'plan_beams');
            identity.numOfFractions = ...
                planWorkflow.cache.CacheIdentity.nestedField( ...
                pln,{'numOfFractions'},[]);
            identity.gantryAngles = ...
                planWorkflow.cache.CacheIdentity.nestedField( ...
                pln,{'propStf','gantryAngles'},[]);
            identity.couchAngles = ...
                planWorkflow.cache.CacheIdentity.nestedField( ...
                pln,{'propStf','couchAngles'},[]);
            identity.bixelWidth = ...
                planWorkflow.cache.CacheIdentity.nestedField( ...
                pln,{'propStf','bixelWidth'},[]);
            identity.numOfBeams = ...
                planWorkflow.cache.CacheIdentity.nestedField( ...
                pln,{'propStf','numOfBeams'},[]);
            identity.isoCenter = ...
                planWorkflow.cache.CacheIdentity.nestedField( ...
                pln,{'propStf','isoCenter'},[]);
        end

        function identity = scenarioIdentity(runConfig,pln,artifact)
            identity = struct();
            scenario = ...
                planWorkflow.cache.CacheIdentity.scenarioForArtifact( ...
                runConfig,artifact);
            fields = fieldnames(scenario);
            for i = 1:numel(fields)
                identity.(fields{i}) = scenario.(fields{i});
            end

            if isstruct(pln) && isfield(pln,'multScen') && ...
                    isa(pln.multScen,'matRad_ScenarioModel')
                identity.fingerprint = ...
                    planWorkflow.cache.CacheIdentity.scenarioFingerprint( ...
                    pln.multScen);
                identity.numScenarios = pln.multScen.numScenarios();
            else
                identity.fingerprint = '';
                identity.numScenarios = [];
            end
        end

        function identity = scenarioModelIdentity(multScen)
            identity = struct();
            if isempty(multScen) || ~isa(multScen,'matRad_ScenarioModel')
                identity.className = '';
                return;
            end

            identity.className = class(multScen);
            identity.name = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'name','');
            identity.shortName = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'shortName','');
            identity.numScenarios = multScen.numScenarios();
            identity.scenarioIds = multScen.scenarioIds();
            identity.scenarioDimensionActive = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'scenarioDimensionActive',{});
            identity.scenarioComponents = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'scenarioComponents',struct([]));
            identity.scenarioValueNames = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'scenarioValueNames',{});
            identity.scenarioValues = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'scenarioValues',[]);
            identity.scenarioCtScenIds = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'scenarioCtScenIds',[]);
            identity.scenarioStoragePolicy = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'scenarioStoragePolicy','');
            identity.scenarioStorageSubscripts = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'scenarioStorageSubscripts',[]);
            identity.dijContainerSize = multScen.getDijContainerSize();
            identity.dijActiveMaskHash = ...
                planWorkflow.cache.CacheIdentity.valueHash( ...
                multScen.getDijActiveMask());
            identity.ctScenProb = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'ctScenProb',[]);
            identity.scenProb = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'scenProb',[]);
            identity.scenWeight = ...
                planWorkflow.cache.CacheIdentity.objectProperty( ...
                multScen,'scenWeight',[]);
            identity.uncertainty = ...
                planWorkflow.cache.CacheIdentity.scenarioUncertaintyIdentity( ...
                multScen);
        end

        function identity = scenarioUncertaintyIdentity(multScen)
            fields = {'rangeRelSD','rangeAbsSD','shiftSD','gantryAngleSD', ...
                      'couchAngleSD','numOfBeams','wcSigma'};
            identity = struct();
            for i = 1:numel(fields)
                identity.(fields{i}) = ...
                    planWorkflow.cache.CacheIdentity.objectProperty( ...
                    multScen,fields{i},[]);
            end
        end

        function identity = intervalIdentity(context)
            identity = struct();
            if ~isfield(context,'interval') || isempty(context.interval)
                return;
            end
            identity = context.interval;
        end

        function identity = probIdentity(context)
            identity = struct();
            if ~isfield(context,'prob') || isempty(context.prob)
                return;
            end
            identity = context.prob;
        end

        function tag = physicalTag(artifact)
            switch artifact.kind
                case {'reference','robust'}
                    tag = 'dij';
                otherwise
                    tag = artifact.kind;
            end
        end

        function artifactOut = physicalArtifact(artifact)
            artifactOut = struct();
            artifactOut.kind = planWorkflow.cache.CacheIdentity.physicalTag( ...
                artifact);
            if any(strcmp(artifact.kind,{'interval','prob'})) && ...
                    ~isempty(artifact.robustnessMode)
                artifactOut.robustnessMode = artifact.robustnessMode;
            end
        end

        function prefix = scenarioPrefix(artifact)
            switch artifact.kind
                case 'reference'
                    prefix = 'reference';
                otherwise
                    prefix = 'robust';
            end
        end

        function key = relativeKey(runConfig,artifact,identity,shortHash)
            physicalArtifact = identity.artifact;
            folderParts = { ...
                identity.patient.description, ...
                identity.patient.caseID, ...
                identity.modality.radiationMode, ...
                identity.modality.machine, ...
                identity.modality.bioModel, ...
                identity.beam.plan_beams, ...
                physicalArtifact.kind};
            if isfield(physicalArtifact,'robustnessMode') && ...
                    ~isempty(physicalArtifact.robustnessMode)
                folderParts{end + 1} = physicalArtifact.robustnessMode;
            end
            folderParts = cellfun( ...
                @planWorkflow.cache.CacheIdentity.sanitizePathPart, ...
                folderParts,'UniformOutput',false);

            switch artifact.kind
                case {'reference','robust'}
                    scenarioMode = ...
                        planWorkflow.cache.CacheIdentity.scenarioModeForStem( ...
                        runConfig,artifact);
                    fileStem = sprintf('%s_%s', ...
                        planWorkflow.cache.CacheIdentity.sanitizePathPart( ...
                        scenarioMode),shortHash);
                case {'interval','prob'}
                    inputStem = ...
                        planWorkflow.cache.CacheIdentity.derivedInputStem( ...
                        identity);
                    fileStem = sprintf('%s_%s',inputStem,shortHash);
                otherwise
                    fileStem = sprintf('%s_%s', ...
                        planWorkflow.cache.CacheIdentity.sanitizePathPart( ...
                        artifact.kind),shortHash);
            end
            key = fullfile(folderParts{:},fileStem);
        end

        function scenarioMode = scenarioModeForStem(runConfig,artifact)
            scenario = ...
                planWorkflow.cache.CacheIdentity.scenarioForArtifact( ...
                runConfig,artifact);
            scenarioMode = scenario.scen_mode;
            if isempty(scenarioMode)
                scenarioMode = 'scenario';
            end
        end

        function scenario = scenarioForArtifact(runConfig,artifact)
            if strcmp(artifact.kind,'reference')
                reference = ...
                    planWorkflow.config.RobustPlanConfig.referenceFromRunConfig( ...
                    runConfig);
                scenario = ...
                    planWorkflow.config.RobustPlanConfig.matRadScenario( ...
                    reference.scenario);
                return;
            end

            if planWorkflow.cache.CacheIdentity.isNominalRobustArtifact( ...
                    artifact)
                scenario = ...
                    planWorkflow.config.RobustPlanConfig.matRadScenario( ...
                    planWorkflow.config.RobustPlanConfig.defaultScenario( ...
                    'nomScen'));
                return;
            end

            if any(strcmp(artifact.kind,{'robust','interval','prob'}))
                plan = ...
                    planWorkflow.cache.CacheIdentity.robustPlanForArtifact( ...
                    runConfig,artifact);
                scenario = ...
                    planWorkflow.config.RobustPlanConfig.matRadScenario( ...
                    plan.scenario);
                return;
            end

            scenario = ...
                planWorkflow.config.RobustPlanConfig.matRadScenario( ...
                planWorkflow.config.RobustPlanConfig.defaultScenario( ...
                'wcScen'));
        end

        function tf = isNominalRobustArtifact(artifact)
            tf = strcmp(artifact.kind,'robust') && ...
                isfield(artifact,'role') && strcmp(artifact.role,'nominal');
        end

        function plan = robustPlanForArtifact(runConfig,artifact)
            if ~isfield(artifact,'planId') || isempty(artifact.planId)
                error('planWorkflow:cache:CacheIdentity:MissingRobustPlanId', ...
                    ['Robust cache artifacts require an explicit planId. ' ...
                     'Use tags like robust_<planId>, ' ...
                     'robustNominal_<planId>, interval_<planId>, ' ...
                     'or prob_<planId>.']);
            end

            if strcmp(char(artifact.planId),'reference')
                plan = ...
                    planWorkflow.cache.CacheIdentity.referencePlanForArtifact( ...
                    runConfig);
                return;
            end

            plans = ...
                planWorkflow.config.RobustPlanConfig.plansFromRunConfig( ...
                runConfig);
            planIx = find(strcmp({plans.id},char(artifact.planId)),1);
            if isempty(planIx)
                error('planWorkflow:cache:CacheIdentity:UnknownRobustPlanId', ...
                    ['Robust cache artifact references unknown planId ' ...
                     '"%s".'],char(artifact.planId));
            end
            plan = plans(planIx);
        end

        function plan = referencePlanForArtifact(runConfig)
            reference = ...
                planWorkflow.config.RobustPlanConfig.referenceFromRunConfig( ...
                runConfig);
            plan = planWorkflow.config.RobustPlanConfig.defaultPlan();
            plan.id = 'reference';
            plan.label = ...
                planWorkflow.results.PlanLabels.referencePlanDisplayLabel( ...
                reference);
            plan.objectiveSetName = 'reference';
            plan.robustnessMode = reference.robustnessMode;
            plan.scenario = reference.scenario;
            plan.optimization4D = reference.optimization4D;
            plan.robustnessOptions = reference.robustnessOptions;
            plan.dosePrecompute = reference.dosePrecompute;
            plan.variants = reference.variants;
        end

        function metadata = robustPlanMetadata(plan)
            metadata = struct();
            metadata.planId = char(plan.id);
            metadata.label = char(plan.label);
            metadata.robustnessMode = char(plan.robustnessMode);
            metadata.objectiveSetName = char(plan.objectiveSetName);
            metadata.scenario = plan.scenario;
            metadata.robustnessOptions = plan.robustnessOptions;
            metadata.optimization4D = plan.optimization4D;
        end

        function value = configText(config,fieldName)
            value = '';
            if isstruct(config) && isfield(config,fieldName) && ...
                    ~isempty(config.(fieldName))
                value = char(config.(fieldName));
            end
        end

        function value = configValue(config,fieldName,defaultValue)
            if isstruct(config) && isfield(config,fieldName)
                value = config.(fieldName);
            else
                value = defaultValue;
            end
        end

        function value = bioParamField(bioParam,fieldName,defaultValue)
            if nargin < 3
                defaultValue = '';
            end
            value = defaultValue;
            if isstruct(bioParam) && isfield(bioParam,fieldName)
                value = bioParam.(fieldName);
            elseif isobject(bioParam) && isprop(bioParam,fieldName)
                value = bioParam.(fieldName);
            end
            if ischar(value) || isstring(value)
                value = char(value);
            end
        end

        function value = nestedField(value,fieldPath,defaultValue)
            for i = 1:numel(fieldPath)
                fieldName = fieldPath{i};
                if isstruct(value) && isfield(value,fieldName)
                    value = value.(fieldName);
                else
                    value = defaultValue;
                    return;
                end
            end
        end

        function fileStem = derivedInputStem(identity)
            inputIdentity = identity;
            inputIdentity.tag = 'dij';
            inputIdentity.artifact = struct('kind','dij');
            derivedFields = {'interval','prob'};
            for fieldIx = 1:numel(derivedFields)
                if isfield(inputIdentity,derivedFields{fieldIx})
                    inputIdentity = rmfield(inputIdentity, ...
                        derivedFields{fieldIx});
                end
            end

            canonicalInput = ...
                planWorkflow.cache.CacheIdentity.canonicalize( ...
                inputIdentity);
            inputHash = planWorkflow.cache.CacheIdentity.sha256( ...
                jsonencode(canonicalInput));
            scenarioMode = ...
                planWorkflow.cache.CacheIdentity.scenarioModeFromIdentity( ...
                canonicalInput);
            fileStem = sprintf('%s_%s', ...
                planWorkflow.cache.CacheIdentity.sanitizePathPart( ...
                scenarioMode),inputHash(1:16));
        end

        function scenarioMode = scenarioModeFromIdentity(identity)
            scenarioMode = 'scenario';
            if isstruct(identity) && isfield(identity,'scenario') && ...
                    isstruct(identity.scenario) && ...
                    isfield(identity.scenario,'scen_mode') && ...
                    ~isempty(identity.scenario.scen_mode)
                scenarioMode = char(identity.scenario.scen_mode);
            end
        end

        function value = doseGridResolution(pln)
            value = [];
            if ~isstruct(pln) || ~isfield(pln,'propDoseCalc') || ...
                    ~isfield(pln.propDoseCalc,'doseGrid') || ...
                    ~isfield(pln.propDoseCalc.doseGrid,'resolution')
                return;
            end
            resolution = pln.propDoseCalc.doseGrid.resolution;
            if all(isfield(resolution,{'x','y','z'}))
                value = [resolution.x resolution.y resolution.z];
            end
        end

        function value = cellText(cst,rowIx,colIx)
            value = '';
            if size(cst,1) >= rowIx && size(cst,2) >= colIx && ...
                    ~isempty(cst{rowIx,colIx})
                value = char(cst{rowIx,colIx});
            end
        end

        function value = structureProperty(cst,rowIx,propertyName)
            value = [];
            if size(cst,2) < 5 || ~isstruct(cst{rowIx,5}) || ...
                    ~isfield(cst{rowIx,5},propertyName)
                return;
            end
            value = cst{rowIx,5}.(propertyName);
        end

        function value = objectProperty(object,propertyName,defaultValue)
            value = defaultValue;
            if ~isprop(object,propertyName)
                return;
            end
            try
                value = object.(propertyName);
            catch
                value = defaultValue;
            end
        end

        function value = canonicalize(value)
            if isstruct(value)
                for elementIx = 1:numel(value)
                    fields = fieldnames(value(elementIx));
                    for fieldIx = 1:numel(fields)
                        fieldName = fields{fieldIx};
                        value(elementIx).(fieldName) = ...
                            planWorkflow.cache.CacheIdentity.canonicalize( ...
                            value(elementIx).(fieldName));
                    end
                end
                value = orderfields(value);
            elseif iscell(value)
                for i = 1:numel(value)
                    value{i} = ...
                        planWorkflow.cache.CacheIdentity.canonicalize( ...
                        value{i});
                end
            elseif issparse(value)
                value = full(value);
            elseif isstring(value)
                value = cellstr(value);
                if isscalar(value)
                    value = value{1};
                end
            end
        end

        function hash = sha256(text)
            digest = java.security.MessageDigest.getInstance('SHA-256');
            digest.update(uint8(char(text)));
            bytes = typecast(digest.digest(),'uint8');
            hash = lower(sprintf('%02X',bytes));
        end

        function value = sanitizePathPart(value)
            value = char(value);
            if isempty(value)
                value = 'unspecified';
            end
            value = regexprep(value,'[^a-zA-Z0-9._-]','_');
            value = regexprep(value,'_+','_');
        end
    end
end
