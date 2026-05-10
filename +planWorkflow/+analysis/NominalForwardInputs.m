classdef NominalForwardInputs
    % NominalForwardInputs Builds nominal forward-dose inputs for analysis.

    methods (Static)
        function [stf,pln] = robustVariant(robustData,variantResult)
            pln = planWorkflow.results.VariantPlanResolver.resolve( ...
                robustData,variantResult);
            stf = planWorkflow.analysis.NominalForwardInputs.nominalStf( ...
                robustData);
            pln = planWorkflow.analysis.NominalForwardInputs.nominalPlan( ...
                robustData,pln);
        end

        function pln = nominalPlan(robustData,pln)
            pln = ...
                planWorkflow.analysis.NominalForwardInputs.removeOptimizationPayload( ...
                pln);

            [scenarioModel,hasScenarioModel] = ...
                planWorkflow.analysis.NominalForwardInputs.nominalScenarioModel( ...
                robustData,pln);
            if hasScenarioModel
                pln.multScen = scenarioModel;
                return;
            end

            if isfield(robustData,'ct') && ~isempty(robustData.ct)
                nominalScenario = ...
                    planWorkflow.analysis.NominalForwardInputs.nominalScenarioConfig( ...
                    robustData,pln);
                pln.multScen = planWorkflow.scenario.createModel( ...
                    robustData.ct,nominalScenario.scen_mode, ...
                    nominalScenario,'optimization');
            end
        end
    end

    methods (Static, Access = private)
        function stf = nominalStf(robustData)
            if isfield(robustData,'stfNominal') && ...
                    ~isempty(robustData.stfNominal)
                stf = robustData.stfNominal;
            else
                stf = robustData.stf;
            end
        end

        function [scenarioModel,hasScenarioModel] = ...
                nominalScenarioModel(robustData,pln)
            scenarioModel = [];
            hasScenarioModel = false;
            candidateModels = ...
                planWorkflow.analysis.NominalForwardInputs.candidateModels( ...
                robustData,pln);

            for modelIx = 1:numel(candidateModels)
                [scenarioModel,hasScenarioModel] = ...
                    planWorkflow.analysis.NominalForwardInputs.extractNominalScenario( ...
                    candidateModels{modelIx},robustData);
                if hasScenarioModel
                    return;
                end
            end
        end

        function candidateModels = candidateModels(robustData,pln)
            candidateModels = {};
            if isfield(pln,'multScen') && ~isempty(pln.multScen)
                candidateModels{end + 1} = pln.multScen; %#ok<AGROW>
            end
            if isfield(robustData,'plnNominal') && ...
                    isfield(robustData.plnNominal,'multScen') && ...
                    ~isempty(robustData.plnNominal.multScen)
                candidateModels{end + 1} = ...
                    robustData.plnNominal.multScen; %#ok<AGROW>
            end
            if isfield(robustData,'pln') && ...
                    isfield(robustData.pln,'multScen') && ...
                    ~isempty(robustData.pln.multScen)
                candidateModels{end + 1} = ...
                    robustData.pln.multScen; %#ok<AGROW>
            end
        end

        function [scenarioModel,hasScenarioModel] = ...
                extractNominalScenario(sourceModel,robustData)
            scenarioModel = [];
            hasScenarioModel = false;
            if isempty(sourceModel) || ...
                    ~ismethod(sourceModel,'getNominalScenarioIds') || ...
                    ~ismethod(sourceModel,'extractSingleScenario')
                return;
            end

            nominalIds = sourceModel.getNominalScenarioIds();
            if isempty(nominalIds)
                return;
            end

            scenarioId = ...
                planWorkflow.analysis.NominalForwardInputs.selectNominalScenarioId( ...
                sourceModel,nominalIds,robustData);
            scenarioModel = sourceModel.extractSingleScenario(scenarioId);
            hasScenarioModel = true;
        end

        function scenarioId = selectNominalScenarioId( ...
                sourceModel,nominalIds,robustData)
            scenarioId = nominalIds(1);
            referenceCtScenarioId = ...
                planWorkflow.analysis.NominalForwardInputs.referenceCtScenarioId( ...
                robustData);
            if isempty(referenceCtScenarioId) || ...
                    ~ismethod(sourceModel,'getCtScenario')
                return;
            end

            ctScenarioIds = arrayfun(@(id) ...
                sourceModel.getCtScenario(id),nominalIds);
            matchingIx = find(ctScenarioIds == referenceCtScenarioId,1,'first');
            if ~isempty(matchingIx)
                scenarioId = nominalIds(matchingIx);
            end
        end

        function scenario = nominalScenarioConfig(robustData,pln)
            scenario = ...
                planWorkflow.config.RobustPlanConfig.defaultScenario( ...
                'nomScen');
            scenario.ctActive = false;
            scenario.setupActive = false;
            scenario.rangeActive = false;
            scenario.gantryActive = false;
            scenario.couchActive = false;

            referenceCtScenarioId = ...
                planWorkflow.analysis.NominalForwardInputs.referenceCtScenarioId( ...
                robustData);
            if ~isempty(referenceCtScenarioId)
                scenario.ctReferenceScenId = referenceCtScenarioId;
            end

            scenario = ...
                planWorkflow.config.RobustPlanConfig.matRadScenario( ...
                scenario);
            scenario = planWorkflow.config.ScenarioSpec.withBeamCount( ...
                scenario,pln);
        end

        function referenceCtScenarioId = referenceCtScenarioId(robustData)
            referenceCtScenarioId = [];
            if isfield(robustData,'dij_prob2') && ...
                    isfield(robustData.dij_prob2,'refScen') && ...
                    ~isempty(robustData.dij_prob2.refScen)
                referenceCtScenarioId = robustData.dij_prob2.refScen;
                return;
            end

            if isfield(robustData,'planConfig') && ...
                    isfield(robustData.planConfig,'scenario') && ...
                    isfield(robustData.planConfig.scenario, ...
                    'ctReferenceScenId') && ...
                    ~isempty(robustData.planConfig.scenario.ctReferenceScenId)
                referenceCtScenarioId = ...
                    robustData.planConfig.scenario.ctReferenceScenId;
            end
        end

        function pln = removeOptimizationPayload(pln)
            if ~isfield(pln,'propOpt') || ~isstruct(pln.propOpt)
                return;
            end

            optimizationOnlyFields = {'scen4D','dij_interval','dij_prob2'};
            for fieldIx = 1:numel(optimizationOnlyFields)
                fieldName = optimizationOnlyFields{fieldIx};
                if isfield(pln.propOpt,fieldName)
                    pln.propOpt = rmfield(pln.propOpt,fieldName);
                end
            end
        end
    end
end
