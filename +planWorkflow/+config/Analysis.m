classdef Analysis
    % Analysis Strict defaults and normalization for workflow analysis config.

    methods (Static)
        function analysis = defaults()
            analysis = struct();
            analysis.evaluationMode = 'perFraction';
            analysis.doseWindow = [];
            analysis.doseWindowDvh = [];
            analysis.doseWindowUncertainty = [];
            analysis.doseWindowRelativeUncertainty1 = [];
            analysis.doseWindowRelativeUncertainty2 = [];
            analysis.doseWindowUvh = [];
            analysis.gammaWindow = [0 1];
            analysis.gammaCriteria = [3 3];
            analysis.robustnessCriteria = [5 5];
            analysis.robustnessTargetMode = 'all';
            analysis.robustnessTargets = [];
            analysis.endpoints = [];
            analysis.endpointsFile = '';
            analysis.figures = struct( ...
                'save',true, ...
                'visible','auto', ...
                'closeAfterSave',true);
        end

        function analysis = normalize(analysis)
            defaults = planWorkflow.config.Analysis.defaults();
            if nargin < 1 || isempty(analysis)
                analysis = struct();
            end

            planWorkflow.config.Analysis.validateFields(analysis,defaults);

            defaultFields = fieldnames(defaults);
            for i = 1:numel(defaultFields)
                fieldName = defaultFields{i};
                if ~isfield(analysis,fieldName)
                    analysis.(fieldName) = defaults.(fieldName);
                end
            end
            analysis.endpointsFile = ...
                planWorkflow.analysis.ClinicalEndpointCatalog.normalizeFileSelection( ...
                analysis.endpointsFile);
            analysis.figures = ...
                planWorkflow.config.Analysis.normalizeFigures( ...
                analysis.figures);

            [~,analysis.evaluationMode] = matRad_convertToEvaluationMode( ...
                [],struct('numOfFractions',1),analysis.evaluationMode);
        end

        function analysis = applyPrescriptionDefaults(analysis,prescriptionDose,pln)
            analysis = planWorkflow.config.Analysis.normalize(analysis);
            prescriptionDose = matRad_convertToEvaluationMode( ...
                prescriptionDose/pln.numOfFractions,pln,analysis.evaluationMode);

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
                    error('planWorkflow:config:Analysis:UnsupportedField', ...
                        'Unsupported analysis field "%s". Valid fields are: %s.', ...
                        analysisFields{i},strjoin(defaultFields',', '));
                end
            end
        end

        function figures = normalizeFigures(figures)
            defaults = planWorkflow.config.Analysis.defaults();
            defaults = defaults.figures;
            if nargin < 1 || isempty(figures)
                figures = defaults;
                return;
            end
            if ~isstruct(figures) || ~isscalar(figures)
                error('planWorkflow:config:Analysis:InvalidFigures', ...
                    'runConfig.analysis.figures must be a scalar struct.');
            end
            allowedFields = fieldnames(defaults);
            fields = fieldnames(figures);
            for i = 1:numel(fields)
                if ~isfield(defaults,fields{i})
                    error('planWorkflow:config:Analysis:UnsupportedFigureField', ...
                        ['Unsupported analysis.figures field "%s". ' ...
                         'Valid fields are: %s.'],fields{i}, ...
                        strjoin(allowedFields',', '));
                end
            end
            for i = 1:numel(allowedFields)
                fieldName = allowedFields{i};
                if ~isfield(figures,fieldName)
                    figures.(fieldName) = defaults.(fieldName);
                end
            end
            figures.save = planWorkflow.config.ConfigValue.logicalScalar( ...
                figures.save,'runConfig.analysis.figures.save', ...
                'planWorkflow:config:Analysis:InvalidFigureSave');
            figures.closeAfterSave = ...
                planWorkflow.config.ConfigValue.logicalScalar( ...
                figures.closeAfterSave, ...
                'runConfig.analysis.figures.closeAfterSave', ...
                'planWorkflow:config:Analysis:InvalidFigureCloseAfterSave');
            figures.visible = ...
                planWorkflow.config.Analysis.normalizeFigureVisibility( ...
                figures.visible);
        end

        function value = normalizeFigureVisibility(value)
            if isstring(value) && isscalar(value)
                value = char(value);
            end
            if islogical(value) || isnumeric(value)
                if ~isscalar(value)
                    error('planWorkflow:config:Analysis:InvalidFigureVisibility', ...
                        ['runConfig.analysis.figures.visible must be ' ...
                         '''auto'', ''on'', ''off'', or a logical scalar.']);
                end
                if logical(value)
                    value = 'on';
                else
                    value = 'off';
                end
                return;
            end
            if ~ischar(value)
                error('planWorkflow:config:Analysis:InvalidFigureVisibility', ...
                    ['runConfig.analysis.figures.visible must be ' ...
                     '''auto'', ''on'', ''off'', or a logical scalar.']);
            end
            value = lower(strtrim(value));
            if ~any(strcmp(value,{'auto','on','off'}))
                error('planWorkflow:config:Analysis:InvalidFigureVisibility', ...
                    ['runConfig.analysis.figures.visible must be ' ...
                     '''auto'', ''on'', ''off'', or a logical scalar.']);
            end
        end
    end
end
