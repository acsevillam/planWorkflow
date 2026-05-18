classdef PlanOptimizationService
    % PlanOptimizationService Owns optimization plan construction/execution.

    methods (Static)
        function resultGUI = runFluenceOptimization( ...
                runConfig,dij,cst,pln,initialWeights)
            if ~isfield(pln,'propOpt') || ~isstruct(pln.propOpt)
                pln.propOpt = struct();
            end
            pln.propOpt.optimizer = runConfig.optimizer;
            if isfield(runConfig,'optimizerOptions')
                pln.propOpt.optimizerOptions = ...
                    planWorkflow.config.OptimizerOptions.normalize( ...
                    runConfig.optimizerOptions);
            else
                pln.propOpt.optimizerOptions = struct();
            end
            if nargin >= 5 && ~isempty(initialWeights) && ...
                    planWorkflow.optimization.PlanOptimizationService.supportsMatRadWarmStart( ...
                    dij,pln)
                resultGUI = matRad_fluenceOptimization( ...
                    dij,cst,pln,initialWeights);
            else
                if nargin >= 5 && ~isempty(initialWeights)
                    planWorkflow.optimization.PlanOptimizationService.warnWarmStartSkipped( ...
                        dij,pln);
                end
                resultGUI = matRad_fluenceOptimization(dij,cst,pln);
            end
        end

        function pln = apply4DConfig(pln,planConfig)
            if ~isfield(pln,'propOpt') || ~isstruct(pln.propOpt)
                pln.propOpt = struct();
            end

            if planWorkflow.optimization.PlanOptimizationService.optimization4DEnabled( ...
                    planConfig)
                pln.propOpt.scen4D = planConfig.optimization4D.scen4D;
            elseif isfield(pln.propOpt,'scen4D')
                pln.propOpt = rmfield(pln.propOpt,'scen4D');
            end
        end

        function tf = optimization4DEnabled(planConfig)
            tf = isstruct(planConfig) && ...
                isfield(planConfig,'optimization4D') && ...
                isstruct(planConfig.optimization4D) && ...
                isfield(planConfig.optimization4D,'enabled') && ...
                logical(planConfig.optimization4D.enabled);
        end
    end

    methods (Static, Access = private)
        function tf = supportsMatRadWarmStart(dij,pln)
            reason = ...
                planWorkflow.optimization.PlanOptimizationService.warmStartSkipReason( ...
                dij,pln);
            tf = isempty(reason);
        end

        function reason = warmStartSkipReason(dij,pln)
            reason = '';
            if ~planWorkflow.optimization.PlanOptimizationService.isBiologicalOptimization( ...
                    pln)
                return;
            end
            if ~isstruct(dij) || ~isfield(dij,'ax') || ...
                    ~isfield(dij,'bx')
                reason = 'missingAxBx';
                return;
            end
            if iscell(dij.ax) || iscell(dij.bx)
                reason = ...
                    planWorkflow.optimization.PlanOptimizationService.cellAxBxSkipReason( ...
                    dij);
                return;
            end
            if ~isnumeric(dij.ax) || ~isnumeric(dij.bx)
                reason = 'nonNumericAxBx';
                return;
            end
            if ~isequal(size(dij.ax),size(dij.bx))
                reason = 'sizeMismatch';
            end
        end

        function reason = cellAxBxSkipReason(dij)
            reason = '';
            if ~iscell(dij.ax) || ~iscell(dij.bx)
                reason = 'mixedCellAxBx';
                return;
            end
            if numel(dij.ax) ~= numel(dij.bx)
                reason = 'sizeMismatch';
                return;
            end

            numOfVoxels = ...
                planWorkflow.optimization.PlanOptimizationService.doseGridNumOfVoxels( ...
                dij);
            for scenIx = 1:numel(dij.ax)
                if ~isnumeric(dij.ax{scenIx}) || ...
                        ~isnumeric(dij.bx{scenIx})
                    reason = 'nonNumericAxBx';
                    return;
                end
                if ~isequal(size(dij.ax{scenIx}),size(dij.bx{scenIx}))
                    reason = 'sizeMismatch';
                    return;
                end
                if ~isempty(numOfVoxels) && ...
                        (numel(dij.ax{scenIx}) ~= numOfVoxels || ...
                         numel(dij.bx{scenIx}) ~= numOfVoxels)
                    reason = 'sizeMismatch';
                    return;
                end
            end
        end

        function numOfVoxels = doseGridNumOfVoxels(dij)
            numOfVoxels = [];
            if isfield(dij,'doseGrid') && isstruct(dij.doseGrid) && ...
                    isfield(dij.doseGrid,'numOfVoxels') && ...
                    isnumeric(dij.doseGrid.numOfVoxels) && ...
                    isscalar(dij.doseGrid.numOfVoxels)
                numOfVoxels = dij.doseGrid.numOfVoxels;
            end
        end

        function tf = isBiologicalOptimization(pln)
            quantityOpt = ...
                planWorkflow.optimization.PlanOptimizationService.quantityOpt( ...
                pln);
            tf = any(strcmp(quantityOpt,{'effect','RBExDose','BED'}));
        end

        function warnWarmStartSkipped(dij,pln)
            if ~planWorkflow.optimization.PlanOptimizationService.isBiologicalOptimization( ...
                    pln)
                return;
            end

            radiationMode = ...
                planWorkflow.optimization.PlanOptimizationService.fieldText( ...
                pln,'radiationMode');
            quantityOpt = ...
                planWorkflow.optimization.PlanOptimizationService.quantityOpt( ...
                pln);
            axClass = ...
                planWorkflow.optimization.PlanOptimizationService.fieldClass( ...
                dij,'ax');
            bxClass = ...
                planWorkflow.optimization.PlanOptimizationService.fieldClass( ...
                dij,'bx');
            axSize = ...
                planWorkflow.optimization.PlanOptimizationService.fieldSizeText( ...
                dij,'ax');
            bxSize = ...
                planWorkflow.optimization.PlanOptimizationService.fieldSizeText( ...
                dij,'bx');
            reason = ...
                planWorkflow.optimization.PlanOptimizationService.warmStartSkipReason( ...
                dij,pln);
            if isempty(reason)
                return;
            end
            key = sprintf('%s|%s|%s|%s|%s|%s|%s',radiationMode, ...
                quantityOpt,reason,axClass,bxClass,axSize,bxSize);

            if planWorkflow.optimization.PlanOptimizationService.alreadyWarned( ...
                    key)
                return;
            end

            warning('planWorkflow:optimization:WarmStartSkipped', ...
                ['Skipping matRad warm start for biological optimization ' ...
                 'because dij.ax/dij.bx are invalid for biological ' ...
                 'optimization warm start. reason=%s, radiationMode=%s, ' ...
                 'quantityOpt=%s, dij.ax class=%s, dij.ax size=%s, ' ...
                 'dij.bx class=%s, dij.bx size=%s.'], ...
                reason,radiationMode,quantityOpt,axClass,axSize, ...
                bxClass,bxSize);
        end

        function tf = alreadyWarned(key)
            persistent warnedKeys
            if isempty(warnedKeys)
                warnedKeys = {};
            end
            tf = any(strcmp(warnedKeys,key));
            if ~tf
                warnedKeys{end + 1} = key;
            end
        end

        function value = quantityOpt(pln)
            value = '<unknown>';
            if ~planWorkflow.optimization.PlanOptimizationService.hasMember( ...
                    pln,'propOpt')
                return;
            end

            propOpt = ...
                planWorkflow.optimization.PlanOptimizationService.memberValue( ...
                pln,'propOpt');
            if planWorkflow.optimization.PlanOptimizationService.hasMember( ...
                    propOpt,'quantityOpt')
                rawValue = ...
                    planWorkflow.optimization.PlanOptimizationService.memberValue( ...
                    propOpt,'quantityOpt');
                value = ...
                    planWorkflow.optimization.PlanOptimizationService.textValue( ...
                    rawValue);
            end
        end

        function value = fieldText(s,fieldName)
            value = '<unknown>';
            if planWorkflow.optimization.PlanOptimizationService.hasMember( ...
                    s,fieldName)
                rawValue = ...
                    planWorkflow.optimization.PlanOptimizationService.memberValue( ...
                    s,fieldName);
                value = ...
                    planWorkflow.optimization.PlanOptimizationService.textValue( ...
                    rawValue);
            end
        end

        function value = fieldClass(s,fieldName)
            if planWorkflow.optimization.PlanOptimizationService.hasMember( ...
                    s,fieldName)
                rawValue = ...
                    planWorkflow.optimization.PlanOptimizationService.memberValue( ...
                    s,fieldName);
                value = class(rawValue);
            else
                value = '<missing>';
            end
        end

        function value = fieldSizeText(s,fieldName)
            if planWorkflow.optimization.PlanOptimizationService.hasMember( ...
                    s,fieldName)
                rawValue = ...
                    planWorkflow.optimization.PlanOptimizationService.memberValue( ...
                    s,fieldName);
                value = mat2str(size(rawValue));
            else
                value = '<missing>';
            end
        end

        function tf = hasMember(value,memberName)
            tf = (isstruct(value) && isfield(value,memberName)) || ...
                (isobject(value) && isprop(value,memberName));
        end

        function value = memberValue(source,memberName)
            value = source.(memberName);
        end

        function value = textValue(rawValue)
            if isempty(rawValue)
                value = '<unknown>';
            elseif ischar(rawValue) || ...
                    (isstring(rawValue) && isscalar(rawValue))
                value = char(rawValue);
            elseif isnumeric(rawValue) && isscalar(rawValue)
                value = num2str(rawValue);
            elseif islogical(rawValue) && isscalar(rawValue)
                value = mat2str(rawValue);
            else
                value = class(rawValue);
            end
        end
    end
end
