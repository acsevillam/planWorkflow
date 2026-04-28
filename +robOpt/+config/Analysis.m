classdef Analysis
    % Analysis Strict defaults and normalization for workflow analysis config.

    methods (Static)
        function analysis = defaults()
            analysis = struct();
            analysis.displayDoseMode = 'perFraction';
            analysis.doseWindow = [];
            analysis.doseWindowDvh = [];
            analysis.doseWindowUncertainty = [];
            analysis.doseWindowRelativeUncertainty1 = [];
            analysis.doseWindowRelativeUncertainty2 = [];
            analysis.doseWindowUvh = [];
            analysis.gammaWindow = [0 1];
            analysis.gammaCriteria = [3 3];
            analysis.robustnessCriteria = [5 5];
        end

        function analysis = normalize(analysis)
            defaults = robOpt.config.Analysis.defaults();
            if nargin < 1 || isempty(analysis)
                analysis = struct();
            end

            robOpt.config.Analysis.validateFields(analysis,defaults);

            defaultFields = fieldnames(defaults);
            for i = 1:numel(defaultFields)
                fieldName = defaultFields{i};
                if ~isfield(analysis,fieldName)
                    analysis.(fieldName) = defaults.(fieldName);
                end
            end

            [~,analysis.displayDoseMode] = matRad_getDisplayDoseScale( ...
                struct('numOfFractions',1),analysis.displayDoseMode);
        end

        function analysis = applyPrescriptionDefaults(analysis,prescriptionDose,pln)
            analysis = robOpt.config.Analysis.normalize(analysis);
            displayDoseScale = matRad_getDisplayDoseScale( ...
                pln,analysis.displayDoseMode);
            prescriptionDose = prescriptionDose/pln.numOfFractions * displayDoseScale;

            if isempty(analysis.doseWindow)
                analysis.doseWindow = [0 prescriptionDose * 1.25];
            end
            if isempty(analysis.doseWindowDvh)
                analysis.doseWindowDvh = [0 prescriptionDose * 1.6];
            end
            if isempty(analysis.doseWindowUncertainty)
                analysis.doseWindowUncertainty = [0 prescriptionDose * 0.5];
            end
            if isempty(analysis.doseWindowRelativeUncertainty1)
                analysis.doseWindowRelativeUncertainty1 = [0 1];
            end
            if isempty(analysis.doseWindowRelativeUncertainty2)
                analysis.doseWindowRelativeUncertainty2 = [0 0.5];
            end
            if isempty(analysis.doseWindowUvh)
                analysis.doseWindowUvh = [0 prescriptionDose * 0.5];
            end
        end

        function validateFields(analysis,defaults)
            defaultFields = fieldnames(defaults);
            analysisFields = fieldnames(analysis);
            for i = 1:numel(analysisFields)
                if ~isfield(defaults,analysisFields{i})
                    error('robOpt:config:Analysis:UnsupportedField', ...
                        'Unsupported analysis field "%s". Valid fields are: %s.', ...
                        analysisFields{i},strjoin(defaultFields',', '));
                end
            end
        end
    end
end
