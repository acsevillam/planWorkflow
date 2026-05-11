classdef ScenarioFreeDoseInfluence
    % ScenarioFreeDoseInfluence Shared helpers for compact robust dij flows.

    methods (Static)
        function pln = createNominalOptimizationPlan(pln,dijNominal, ...
                payloadField)
            if isfield(dijNominal,'scenarioModel') && ...
                    ~isempty(dijNominal.scenarioModel)
                pln.multScen = dijNominal.scenarioModel;
            end
            pln = ...
                planWorkflow.precompute.ScenarioFreeDoseInfluence.removePlanPayload( ...
                pln,payloadField);
            if isfield(pln.propOpt,'scen4D')
                pln.propOpt = rmfield(pln.propOpt,'scen4D');
            end
        end

        function scenarioId = nominalScenarioId(pln,compactDij, ...
                errorPrefix,modelLabel)
            if ~isfield(pln,'multScen') || isempty(pln.multScen) || ...
                    ~ismethod(pln.multScen,'getNominalScenarioIds')
                error([char(errorPrefix) ':MissingScenarioModel'], ...
                    'Cannot derive nominal %s dij without pln.multScen.', ...
                    char(modelLabel));
            end

            nominalIds = pln.multScen.getNominalScenarioIds();
            if isempty(nominalIds)
                error([char(errorPrefix) ':MissingNominalRobustScenario'], ...
                    ['The robust dij used for %s calculation does not ' ...
                    'contain a nominal scenario.'],char(modelLabel));
            end

            refScen = 1;
            if isfield(compactDij,'refScen') && ~isempty(compactDij.refScen)
                refScen = compactDij.refScen;
            end
            ctScenIds = arrayfun(@(id) pln.multScen.getCtScenario(id), ...
                nominalIds);
            matchingIx = find(ctScenIds == refScen,1,'first');
            if isempty(matchingIx)
                error([char(errorPrefix) ...
                    ':MissingReferenceNominalRobustScenario'], ...
                    ['The robust dij used for %s calculation does not ' ...
                    'contain a nominal scenario for CT scenario %d.'], ...
                    char(modelLabel),refScen);
            end

            scenarioId = nominalIds(matchingIx);
        end

        function dijOut = extractDijScenario(dijIn,scenarioDijIx, ...
                scenarioModel)
            dijOut = dijIn;
            fieldNames = fieldnames(dijOut);
            for fieldIx = 1:numel(fieldNames)
                fieldName = fieldNames{fieldIx};
                value = dijOut.(fieldName);
                if ~iscell(value) || numel(value) < scenarioDijIx
                    continue;
                end
                scenarioValue = value{scenarioDijIx};
                if ~(isempty(scenarioValue) || isnumeric(scenarioValue) || ...
                        islogical(scenarioValue))
                    continue;
                end

                scenarioCell = cell(1,1,1);
                scenarioCell{1} = scenarioValue;
                dijOut.(fieldName) = scenarioCell;
            end

            dijOut.numOfScenarios = 1;
            dijOut.scenarioModel = scenarioModel;
            dijOut.nominalScenarioDijIx = scenarioDijIx;
            if ismethod(scenarioModel,'scenarioIds')
                ids = scenarioModel.scenarioIds();
                if ~isempty(ids)
                    dijOut.nominalScenarioId = ids(1);
                end
            end
        end

        function pln = removePlanPayload(pln,payloadField)
            if ~isstruct(pln)
                return;
            end
            if ~isfield(pln,'propOpt') || ~isstruct(pln.propOpt)
                pln.propOpt = struct();
                return;
            end
            payloadField = char(payloadField);
            if isfield(pln.propOpt,payloadField)
                pln.propOpt = rmfield(pln.propOpt,payloadField);
            end
        end

        function pln = attachPlanPayload(pln,payloadField,payload)
            if ~isfield(pln,'propOpt') || ~isstruct(pln.propOpt)
                pln.propOpt = struct();
            end
            pln.propOpt.(char(payloadField)) = payload;
        end

        function quantityField = quantityField(compactDij,defaultField)
            quantityField = char(defaultField);
            if ~isfield(compactDij,'quantityField') || ...
                    isempty(compactDij.quantityField)
                return;
            end
            if ~(ischar(compactDij.quantityField) || ...
                    (isstring(compactDij.quantityField) && ...
                    isscalar(compactDij.quantityField)))
                quantityField = '';
                return;
            end
            quantityField = char(compactDij.quantityField);
        end

        function tf = isDijQuantityUsable(dij,quantityField,expectedSize)
            tf = ~isempty(quantityField) && isfield(dij,quantityField) && ...
                iscell(dij.(quantityField)) && ...
                ~isempty(dij.(quantityField)) && ...
                ~isempty(dij.(quantityField){1}) && ...
                isnumeric(dij.(quantityField){1}) && ...
                isequal(size(dij.(quantityField){1}),expectedSize);
        end

        function tf = requiresCompactPrecompute(planConfig)
            tf = planWorkflow.precompute.ScenarioFreeDoseInfluence.requiresIntervalDij( ...
                planConfig) || ...
                planWorkflow.precompute.ScenarioFreeDoseInfluence.requiresProb2Dij( ...
                planConfig);
        end

        function tf = requiresIntervalDij(planConfig)
            tf = isstruct(planConfig) && isfield(planConfig, ...
                'requiresIntervalDij') && logical(planConfig.requiresIntervalDij);
        end

        function tf = requiresProb2Dij(planConfig)
            tf = isstruct(planConfig) && isfield(planConfig, ...
                'requiresProb2Dij') && logical(planConfig.requiresProb2Dij);
        end

        function tf = useStreamingPrecompute(planConfig)
            tf = ...
                planWorkflow.precompute.ScenarioFreeDoseInfluence.requiresCompactPrecompute( ...
                planConfig) && isstruct(planConfig) && ...
                isfield(planConfig,'dosePrecompute') && ...
                isstruct(planConfig.dosePrecompute) && ...
                isfield(planConfig.dosePrecompute,'useStreaming') && ...
                logical(planConfig.dosePrecompute.useStreaming);
        end

        function tf = isReferencePlan(robustData)
            tf = false;
            if ~isstruct(robustData) || ...
                    ~isfield(robustData,'planConfig') || ...
                    ~isstruct(robustData.planConfig) || ...
                    ~isfield(robustData.planConfig,'id')
                return;
            end
            planId = robustData.planConfig.id;
            if ischar(planId) || (isstring(planId) && isscalar(planId))
                tf = strcmp(char(planId),'reference');
            end
        end

        function cfg = streamingConfig(planConfig)
            cfg = struct();
            if ~isstruct(planConfig) || ~isfield(planConfig,'dosePrecompute') || ...
                    ~isstruct(planConfig.dosePrecompute)
                return;
            end
            dosePrecompute = ...
                planWorkflow.config.RobustPlanConfig.normalizeDosePrecompute( ...
                planConfig.dosePrecompute,'dosePrecompute');
            cfg.SecondPassStrategy = dosePrecompute.SecondPassStrategy;
            cfg.KeepCache = dosePrecompute.KeepCache;
            if ~isempty(dosePrecompute.CacheRoot)
                cfg.CacheRoot = dosePrecompute.CacheRoot;
            end
        end

        function cfg = mergeStreamingConfig(cfg,planConfig)
            streamingCfg = ...
                planWorkflow.precompute.ScenarioFreeDoseInfluence.streamingConfig( ...
                planConfig);
            fields = fieldnames(streamingCfg);
            for fieldIx = 1:numel(fields)
                cfg.(fields{fieldIx}) = streamingCfg.(fields{fieldIx});
            end
        end

        function timing = inputTiming(robustData)
            timing = [];
            if isstruct(robustData) && ...
                    isfield(robustData,'dijRobustPrecomputingTiming') && ...
                    ~isempty(robustData.dijRobustPrecomputingTiming)
                timing = robustData.dijRobustPrecomputingTiming;
            elseif isstruct(robustData) && ...
                    isfield(robustData,'dijNominalPrecomputingTiming') && ...
                    ~isempty(robustData.dijNominalPrecomputingTiming)
                timing = robustData.dijNominalPrecomputingTiming;
            end
        end

        function sizeData = inputSize(robustData)
            sizeData = [];
            if isstruct(robustData) && ...
                    isfield(robustData,'dijRobustPrecomputingSize') && ...
                    ~isempty(robustData.dijRobustPrecomputingSize)
                sizeData = robustData.dijRobustPrecomputingSize;
            elseif isstruct(robustData) && ...
                    isfield(robustData,'dijNominalPrecomputingSize') && ...
                    ~isempty(robustData.dijNominalPrecomputingSize)
                sizeData = robustData.dijNominalPrecomputingSize;
            end
        end

        function sizeData = referenceSize(context,robustData)
            sizeData = [];
            if nargin >= 2 && isstruct(robustData) && ...
                    isfield(robustData,'referenceDijPrecomputingSize') && ...
                    ~isempty(robustData.referenceDijPrecomputingSize)
                sizeData = robustData.referenceDijPrecomputingSize;
                return;
            end
            if isstruct(context) && isfield(context,'data') && ...
                    isstruct(context.data) && ...
                    isfield(context.data,'dijPrecomputingSize') && ...
                    ~isempty(context.data.dijPrecomputingSize)
                sizeData = context.data.dijPrecomputingSize;
            end
        end

        function tf = hasNominalOptimizationDij(robustData)
            tf = isstruct(robustData) && ...
                isfield(robustData,'dijNominal') && ...
                ~isempty(robustData.dijNominal) && ...
                isfield(robustData,'plnNominal') && ...
                ~isempty(robustData.plnNominal);
        end
    end
end
