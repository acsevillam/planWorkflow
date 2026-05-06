classdef Plan
    % Plan Modality-aware plan construction helpers.

    methods (Static)
        function [pln,quantityOpt,quantityVis] = create(runConfig,ct,cst,template)
            if nargin < 4
                template = [];
            end

            pln.radiationMode = char(runConfig.radiationMode);
            pln.machine = char(runConfig.machine);
            modelName = planWorkflow.plan.Plan.resolveBioModel(runConfig);
            quantityOpt = ...
                planWorkflow.plan.DoseQuantityResolver.requireFromRunConfig( ...
                runConfig,'runConfig');

            switch pln.radiationMode
                case 'photons'
                    doseEngine = 'SVDPB';
                case 'protons'
                    pln.propDoseCalc.calcLET = ...
                        planWorkflow.plan.Plan.bioModelRequiresLet( ...
                        modelName);
                    doseEngine = 'HongPB';
                case 'helium'
                    pln.propDoseCalc.calcLET = ...
                        planWorkflow.plan.Plan.bioModelRequiresLet( ...
                        modelName);
                    doseEngine = 'HongPB';
                case 'carbon'
                    pln.propDoseCalc.calcLET = ...
                        planWorkflow.plan.Plan.bioModelRequiresLet( ...
                        modelName);
                    doseEngine = 'HongPB';
                otherwise
                    error('planWorkflow:plan:Plan:UnsupportedRadiationMode', ...
                        'Unsupported radiation mode "%s".',pln.radiationMode);
            end

            if ~isfield(runConfig,'plan_template') || isempty(runConfig.plan_template)
                error('planWorkflow:plan:Plan:MissingPlanTemplate', ...
                    ['runConfig.plan_template is required; beam sets are ' ...
                     'defined by plan templates.']);
            end
            pln = planWorkflow.templates.PlanTemplate.applyBeams( ...
                runConfig,pln,ct,cst,template);
            pln = planWorkflow.plan.Plan.applyDoseResolution(runConfig,pln);
            pln.propDoseCalc.engine = doseEngine;
            pln.hlutFileName = runConfig.hlutFileName;
            pln.propOpt.runSequencing = 0;
            pln.propOpt.runDAO = 0;
            pln.propOpt.optimizer = runConfig.optimizer;
            pln.bioParam = matRad_bioModel(pln.radiationMode,quantityOpt,modelName);
            quantityVis = ...
                planWorkflow.plan.DoseQuantityResolver.visualFromPlan( ...
                pln,quantityOpt);
            referenceScenarioConfig = ...
                planWorkflow.plan.Plan.referenceScenarioConfig(runConfig);
            referenceScenarioConfig.numOfBeams = ...
                planWorkflow.plan.Plan.numOfBeams(pln);
            pln.multScen = planWorkflow.scenario.createModel(ct, ...
                referenceScenarioConfig.scen_mode, ...
                referenceScenarioConfig,'optimization');
        end

        function numOfBeams = numOfBeams(pln)
            numOfBeams = 0;
            if isfield(pln,'propStf')
                if isfield(pln.propStf,'numOfBeams') && ...
                        ~isempty(pln.propStf.numOfBeams)
                    numOfBeams = pln.propStf.numOfBeams;
                elseif isfield(pln.propStf,'gantryAngles') && ...
                        ~isempty(pln.propStf.gantryAngles)
                    numOfBeams = numel(pln.propStf.gantryAngles);
                end
            end
        end

        function pln = applyDoseResolution(runConfig,pln)
            pln.propDoseCalc.doseGrid.resolution.x = runConfig.doseResolution(1);
            pln.propDoseCalc.doseGrid.resolution.y = runConfig.doseResolution(2);
            pln.propDoseCalc.doseGrid.resolution.z = runConfig.doseResolution(3);
        end
    end

    methods (Static, Access = private)
        function bioModel = resolveBioModel(runConfig)
            if isfield(runConfig,'bioModel') && ~isempty(runConfig.bioModel)
                bioModel = char(runConfig.bioModel);
            else
                bioModel = ...
                    planWorkflow.matRadCapabilitiesReader.defaultBioModel( ...
                    runConfig.radiationMode);
            end
            supportedBioModels = ...
                planWorkflow.matRadCapabilitiesReader.supportedBioModels( ...
                runConfig.radiationMode);
            if ~any(strcmp(bioModel,supportedBioModels))
                error('planWorkflow:plan:Plan:UnsupportedBioModel', ...
                    ['Biological model "%s" is not supported for ' ...
                     'radiationMode "%s".'],bioModel, ...
                    char(runConfig.radiationMode));
            end
        end

        function tf = bioModelRequiresLet(bioModel)
            tf = any(strcmp(char(bioModel),{'MCN','WED','HEL','LEM'}));
        end

        function scenarioConfig = referenceScenarioConfig(runConfig)
            reference = ...
                planWorkflow.config.RobustPlanConfig.referenceFromRunConfig( ...
                runConfig);
            scenarioConfig = ...
                planWorkflow.config.RobustPlanConfig.matRadScenario( ...
                reference.scenario);
        end
    end
end
