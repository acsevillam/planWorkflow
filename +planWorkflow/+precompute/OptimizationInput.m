classdef OptimizationInput
    % OptimizationInput Canonical ct/cst/stf/dij/pln optimization contract.

    methods (Static)
        function input = build(ct,cst,pln,stf,dij,dijKind,source, ...
                ctReferenceView)
            if nargin < 8 || isempty(ctReferenceView)
                ctReferenceView = ...
                    planWorkflow.precompute.OptimizationInput.emptyCtReferenceView();
            end
            input = struct();
            input.ct = ct;
            input.cst = cst;
            input.pln = pln;
            input.stf = stf;
            input.dij = dij;
            input.dijKind = char(dijKind);
            input.source = char(source);
            input.ctReferenceView = ctReferenceView;
            planWorkflow.precompute.OptimizationInput.validate( ...
                input,char(source));
        end

        function input = require(owner,context)
            if nargin < 2 || isempty(context)
                context = 'optimization';
            end
            input = planWorkflow.precompute.OptimizationInput.requireFullDij( ...
                owner,context);
        end

        function input = requireLight(owner,context)
            if nargin < 2 || isempty(context)
                context = 'optimization';
            end
            if ~isstruct(owner) || ~isfield(owner,'optimizationInput') || ...
                    isempty(owner.optimizationInput)
                error(['planWorkflow:precompute:OptimizationInput:' ...
                    'MissingOptimizationInput'], ...
                    '%s requires optimizationInput.',char(context));
            end
            input = owner.optimizationInput;
            planWorkflow.precompute.OptimizationInput.validateLight( ...
                input,char(context));
        end

        function input = requireFullDij(owner,context,runConfig,cachePath, ...
                rootData,logFn)
            if nargin < 2 || isempty(context)
                context = 'optimization';
            end
            planWorkflow.precompute.OptimizationInput.rejectFullDijForLightStage( ...
                context);
            input = planWorkflow.precompute.OptimizationInput.requireLight( ...
                owner,context);
            if ~planWorkflow.precompute.OptimizationInput.hasFullDij(input)
                if nargin < 3 || isempty(runConfig)
                    error(['planWorkflow:precompute:OptimizationInput:' ...
                        'MissingFullDij'], ...
                        ['%s requires optimizationInput.dij. The workflow ' ...
                         'data only contains a lazy dose-influence artifact.'], ...
                        char(context));
                end
                if nargin < 4 || isempty(cachePath)
                    cachePath = [];
                end
                if nargin < 5 || isempty(rootData)
                    rootData = owner;
                end
                if nargin < 6
                    logFn = [];
                end
                [input,loaded] = ...
                    planWorkflow.persistence.WorkflowDataArtifact.loadOptimizationInputDij( ...
                    owner,runConfig,cachePath,rootData,context);
                if loaded && ~isempty(logFn)
                    logFn(sprintf(['Loaded full dose influence for %s ' ...
                        'from workflow artifact/cache.'],char(context)));
                end
            end
            planWorkflow.precompute.OptimizationInput.validate( ...
                input,char(context));
        end

        function tf = isNominal(input)
            tf = isstruct(input) && isfield(input,'dijKind') && ...
                strcmp(char(input.dijKind),'nominal');
        end

        function validate(input,context)
            if nargin < 2 || isempty(context)
                context = 'optimizationInput';
            end
            planWorkflow.precompute.OptimizationInput.validateLight( ...
                input,context);
            planWorkflow.precompute.OptimizationInput.requireInputField( ...
                input,'dij',context);
            planWorkflow.precompute.OptimizationInput.assertDijStfMatch( ...
                input,context);
        end

        function validateLight(input,context)
            if nargin < 2 || isempty(context)
                context = 'optimizationInput';
            end
            planWorkflow.precompute.OptimizationInput.requireInputField( ...
                input,'ct',context);
            planWorkflow.precompute.OptimizationInput.requireInputField( ...
                input,'cst',context);
            planWorkflow.precompute.OptimizationInput.requireInputField( ...
                input,'pln',context);
            planWorkflow.precompute.OptimizationInput.requireInputField( ...
                input,'stf',context);
            planWorkflow.precompute.OptimizationInput.validateDijKind( ...
                input,context);
            planWorkflow.precompute.OptimizationInput.assertDijStfMatch( ...
                input,context);
        end

        function assertWeightSteeringMatch(input,resultGUI,planId, ...
                variantId,purpose)
            if nargin < 3 || isempty(planId)
                planId = '<unknown>';
            end
            if nargin < 4 || isempty(variantId)
                variantId = '';
            end
            if nargin < 5 || isempty(purpose)
                purpose = 'optimization result';
            end
            planWorkflow.precompute.OptimizationInput.validateLight( ...
                input,purpose);
            if ~isstruct(resultGUI) || ~isfield(resultGUI,'w') || ...
                    isempty(resultGUI.w)
                error(['planWorkflow:precompute:OptimizationInput:' ...
                    'MissingWeights'], ...
                    ['%s for plan "%s" variant "%s" requires ' ...
                     'resultGUI.w.'],char(purpose),char(planId), ...
                    char(variantId));
            end
            expectedBixels = ...
                planWorkflow.precompute.OptimizationInput.totalNumOfBixels( ...
                input.stf);
            if isempty(expectedBixels)
                error(['planWorkflow:precompute:OptimizationInput:' ...
                    'MissingSteeringSize'], ...
                    ['%s for plan "%s" variant "%s" requires ' ...
                     'optimizationInput.stf.totalNumOfBixels.'], ...
                    char(purpose),char(planId),char(variantId));
            end
            if numel(resultGUI.w) ~= expectedBixels
                error(['planWorkflow:precompute:OptimizationInput:' ...
                    'WeightSteeringMismatch'], ...
                    ['%s for plan "%s" variant "%s" has %d weights, ' ...
                     'but optimizationInput.stf has %d bixels.'], ...
                    char(purpose),char(planId),char(variantId), ...
                    numel(resultGUI.w),expectedBixels);
            end
        end

        function count = totalNumOfBixels(value)
            count = [];
            if isstruct(value) && isfield(value,'totalNumOfBixels')
                count = sum([value.totalNumOfBixels]);
            end
        end

        function tf = hasFullDij(input)
            tf = isstruct(input) && isfield(input,'dij') && ...
                ~isempty(input.dij);
        end

        function metadata = emptyCtReferenceView()
            metadata = struct( ...
                'active',false, ...
                'originalCtReferenceScenId',[], ...
                'localCtReferenceScenId',[]);
        end
    end

    methods (Static, Access = private)
        function requireInputField(input,fieldName,context)
            if ~isstruct(input) || ~isfield(input,fieldName) || ...
                    isempty(input.(fieldName))
                error(['planWorkflow:precompute:OptimizationInput:' ...
                    'MissingField'], ...
                    '%s requires optimizationInput.%s.', ...
                    char(context),char(fieldName));
            end
        end

        function validateDijKind(input,context)
            validKinds = {'nominal','scenario','interval','prob'};
            if ~isfield(input,'dijKind') || isempty(input.dijKind) || ...
                    ~any(strcmp(char(input.dijKind),validKinds))
                error(['planWorkflow:precompute:OptimizationInput:' ...
                    'InvalidDijKind'], ...
                    ['%s requires optimizationInput.dijKind to be one ' ...
                     'of nominal, scenario, interval, or prob.'], ...
                    char(context));
            end
        end

        function assertDijStfMatch(input,context)
            dijBixels = ...
                planWorkflow.precompute.OptimizationInput.totalNumOfBixels( ...
                planWorkflow.precompute.OptimizationInput.dijHandle(input));
            stfBixels = ...
                planWorkflow.precompute.OptimizationInput.totalNumOfBixels( ...
                input.stf);
            if isempty(dijBixels) || isempty(stfBixels)
                return;
            end
            if dijBixels ~= stfBixels
                error(['planWorkflow:precompute:OptimizationInput:' ...
                    'DijSteeringMismatch'], ...
                    ['%s selected a dij with %d bixels, but ' ...
                     'optimizationInput.stf has %d bixels.'], ...
                    char(context),dijBixels,stfBixels);
            end
        end

        function value = dijHandle(input)
            value = [];
            if ~isstruct(input)
                return;
            end
            if isfield(input,'dij') && ~isempty(input.dij)
                value = input.dij;
                return;
            end
            if isfield(input,'dijRef') && ~isempty(input.dijRef)
                value = input.dijRef;
                return;
            end
            if isfield(input,'dijInline') && ~isempty(input.dijInline)
                value = input.dijInline;
            end
        end

        function rejectFullDijForLightStage(context)
            text = lower(char(context));
            if ~isempty(strfind(text,'sampling')) || ...
                    ~isempty(strfind(text,'analysis'))
                error(['planWorkflow:precompute:OptimizationInput:' ...
                    'FullDijNotAllowed'], ...
                    ['%s must use requireLight; sampling and analysis ' ...
                     'must not rehydrate full dose-influence matrices.'], ...
                    char(context));
            end
        end
    end
end
