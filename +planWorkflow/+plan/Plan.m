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
            pln.propOpt.quantityOpt = quantityOpt;
            pln.bioParam = matRad_bioModel( ...
                pln.radiationMode,modelName, ...
                planWorkflow.plan.Plan.bioModelInputQuantities(modelName));
            pln.bioModel = pln.bioParam;
            quantityVis = ...
                planWorkflow.plan.DoseQuantityResolver.visualFromPlan( ...
                pln,quantityOpt);
            pln.propOpt.quantityVis = quantityVis;
            referenceScenarioConfig = ...
                planWorkflow.plan.Plan.referenceScenarioConfig(runConfig);
            referenceScenarioConfig.numOfBeams = ...
                planWorkflow.plan.Plan.numOfBeams(pln);
            pln.multScen = planWorkflow.scenario.createModel(ct, ...
                referenceScenarioConfig.scen_mode, ...
                referenceScenarioConfig,'optimization');
            pln = planWorkflow.plan.Plan.applyDoseParallelism(pln,runConfig);
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

        function pln = applyDoseParallelism(pln,runConfig)
            if ~isstruct(pln)
                return;
            end
            hasRunConfig = nargin >= 2;
            if ~hasRunConfig
                runConfig = [];
            end
            if ~isfield(pln,'propDoseCalc') || isempty(pln.propDoseCalc)
                pln.propDoseCalc = struct();
            end
            useParallel = ...
                planWorkflow.plan.Plan.supportsParallelScenarioDij(pln);
            if isstruct(pln.propDoseCalc)
                pln.propDoseCalc.UseParallel = useParallel;
                pln.propDoseCalc = ...
                    planWorkflow.plan.Plan.applyDoseParallelOptions( ...
                    pln.propDoseCalc,useParallel,runConfig,hasRunConfig);
            elseif isobject(pln.propDoseCalc) && ...
                    isprop(pln.propDoseCalc,'UseParallel')
                pln.propDoseCalc.UseParallel = useParallel;
                planWorkflow.plan.Plan.applyDoseEngineParallelOptions( ...
                    pln.propDoseCalc,useParallel,runConfig,hasRunConfig);
            end
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

        function quantities = bioModelInputQuantities(bioModel)
            quantities = {'physicalDose'};
            if planWorkflow.plan.Plan.bioModelRequiresLet(bioModel)
                quantities{end + 1} = 'LET';
            end
            if strcmp(char(bioModel),'LEM')
                quantities = {'physicalDose','alpha','beta'};
            elseif strcmp(char(bioModel),'TAB')
                quantities = {'physicalDose','spectra'};
            end
        end

        function tf = supportsParallelScenarioDij(pln)
            tf = false;
            if ~planWorkflow.plan.Plan.hasMultipleScenarios(pln)
                return;
            end
            if exist('matRad_supportsParallelScenarioDij','file') ~= 2
                planWorkflow.plan.Plan.warnMissingParallelScenarioCapability();
                return;
            end
            [tf,~] = matRad_supportsParallelScenarioDij(pln);
        end

        function warnMissingParallelScenarioCapability()
            persistent warnedMissingHelper
            if ~isempty(warnedMissingHelper) && warnedMissingHelper
                return;
            end
            warning(['planWorkflow:plan:Plan:' ...
                'MissingParallelScenarioCapability'], ...
                ['matRad_supportsParallelScenarioDij is unavailable; ' ...
                 'multi-scenario dose influence calculation will run ' ...
                 'serially.']);
            warnedMissingHelper = true;
        end

        function tf = hasMultipleScenarios(pln)
            tf = false;
            if ~isstruct(pln) || ~isfield(pln,'multScen') || ...
                    isempty(pln.multScen)
                return;
            end
            numScenarios = ...
                planWorkflow.plan.Plan.scenarioCount(pln.multScen);
            tf = ~isempty(numScenarios) && numScenarios > 1;
        end

        function numScenarios = scenarioCount(multScen)
            numScenarios = [];
            if isstruct(multScen)
                if isfield(multScen,'totNumScen') && ...
                        ~isempty(multScen.totNumScen)
                    numScenarios = multScen.totNumScen;
                elseif isfield(multScen,'ctScenProb') && ...
                        ~isempty(multScen.ctScenProb)
                    numScenarios = size(multScen.ctScenProb,1);
                end
            elseif isobject(multScen)
                if isprop(multScen,'totNumScen') && ...
                        ~isempty(multScen.totNumScen)
                    numScenarios = multScen.totNumScen;
                elseif isprop(multScen,'ctScenProb') && ...
                        ~isempty(multScen.ctScenProb)
                    numScenarios = size(multScen.ctScenProb,1);
                end
            end
        end

        function propDoseCalc = applyDoseParallelOptions( ...
                propDoseCalc,useParallel,runConfig,hasRunConfig)
            if isfield(propDoseCalc,'parallelOptions')
                propDoseCalc = rmfield(propDoseCalc,'parallelOptions');
            end
            if ~useParallel || ~hasRunConfig
                return;
            end
            parallelOptions = ...
                planWorkflow.config.Resources.doseParallelOptions( ...
                runConfig);
            if ~isempty(fieldnames(parallelOptions))
                propDoseCalc.parallelOptions = parallelOptions;
            end
        end

        function applyDoseEngineParallelOptions( ...
                propDoseCalc,useParallel,runConfig,hasRunConfig)
            if isprop(propDoseCalc,'parallelOptions')
                propDoseCalc.parallelOptions = struct();
            end
            if ~useParallel || ~hasRunConfig || ...
                    ~isprop(propDoseCalc,'parallelOptions')
                return;
            end
            parallelOptions = ...
                planWorkflow.config.Resources.doseParallelOptions( ...
                runConfig);
            if ~isempty(fieldnames(parallelOptions))
                propDoseCalc.parallelOptions = parallelOptions;
            end
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
