classdef Plan
    % Plan Modality-aware plan construction helpers.

    methods (Static)
        function [pln,quantityOpt] = create(runConfig,ct,cst)
            pln.radiationMode = char(runConfig.radiationMode);
            pln.machine = 'Generic';
            quantityOpt = 'physicalDose';
            modelName = 'none';

            switch pln.radiationMode
                case 'photons'
                    doseEngine = 'SVDPB';
                case 'protons'
                    quantityOpt = 'RBExD';
                    modelName = 'constRBE';
                    pln.propDoseCalc.calcLET = 0;
                    doseEngine = 'HongPB';
                otherwise
                    error('planWorkflow:plan:Plan:UnsupportedRadiationMode', ...
                        'Unsupported radiation mode "%s".',pln.radiationMode);
            end

            pln = planWorkflow.plan.loadBeams(runConfig,pln,ct,cst);
            pln.propDoseCalc.doseGrid.resolution.x = runConfig.doseResolution(1);
            pln.propDoseCalc.doseGrid.resolution.y = runConfig.doseResolution(2);
            pln.propDoseCalc.doseGrid.resolution.z = runConfig.doseResolution(3);
            pln.propDoseCalc.engine = doseEngine;
            pln.hlutFileName = runConfig.hlutFileName;
            pln.propOpt.runSequencing = 0;
            pln.propOpt.runDAO = 0;
            pln.propOpt.optimizer = runConfig.optimizer;
            pln.bioParam = matRad_bioModel(pln.radiationMode,quantityOpt,modelName);
            pln.multScen = matRad_NominalScenario(ct);
        end
    end
end
