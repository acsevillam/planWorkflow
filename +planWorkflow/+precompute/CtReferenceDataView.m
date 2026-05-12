classdef CtReferenceDataView
    % CtReferenceDataView Builds single-CT inputs for inactive CT scenarios.

    methods (Static)
        function [data,scenario,metadata] = apply(data,scenario)
            metadata = struct( ...
                'active',false, ...
                'originalCtReferenceScenId',[], ...
                'localCtReferenceScenId',[]);
            if ~planWorkflow.precompute.CtReferenceDataView.shouldApply( ...
                    data,scenario)
                return;
            end

            refCtScenId = ...
                planWorkflow.precompute.CtReferenceDataView.referenceId( ...
                scenario);
            planWorkflow.precompute.CtReferenceDataView.validateReferenceId( ...
                data.ct,refCtScenId);

            data.ct = ...
                planWorkflow.precompute.CtReferenceDataView.selectCt( ...
                data.ct,refCtScenId);
            data.cst = ...
                planWorkflow.precompute.CtReferenceDataView.selectCst( ...
                data.cst,refCtScenId);

            scenario.ctReferenceScenId = 1;
            if isfield(scenario,'ctScenProb')
                scenario.ctScenProb = [];
            end

            metadata.active = true;
            metadata.originalCtReferenceScenId = refCtScenId;
            metadata.localCtReferenceScenId = 1;
        end

        function tf = shouldApply(data,scenario)
            tf = false;
            if ~isstruct(data) || ~isfield(data,'ct') || ...
                    ~isfield(data,'cst') || isempty(data.ct) || ...
                    isempty(data.cst) || ~isstruct(scenario)
                return;
            end
            if ~isfield(scenario,'ctActive')
                return;
            end
            tf = ~logical(scenario.ctActive);
        end

        function refCtScenId = referenceId(scenario)
            refCtScenId = 1;
            if isfield(scenario,'ctReferenceScenId') && ...
                    ~isempty(scenario.ctReferenceScenId)
                refCtScenId = scenario.ctReferenceScenId;
            end
        end

        function validateReferenceId(ct,refCtScenId)
            valid = isnumeric(refCtScenId) && isscalar(refCtScenId) && ...
                isfinite(refCtScenId) && refCtScenId >= 1 && ...
                round(refCtScenId) == refCtScenId;
            if ~valid
                error(['planWorkflow:precompute:CtReferenceDataView:' ...
                    'InvalidCtReferenceScenario'], ...
                    'ctReferenceScenId must be a positive integer scalar.');
            end
            if isfield(ct,'numOfCtScen') && refCtScenId > ct.numOfCtScen
                error(['planWorkflow:precompute:CtReferenceDataView:' ...
                    'InvalidCtReferenceScenario'], ...
                    'ctReferenceScenId %d exceeds ct.numOfCtScen %d.', ...
                    refCtScenId,ct.numOfCtScen);
            end
        end

        function ct = selectCt(ct,refCtScenId)
            if ~isfield(ct,'numOfCtScen') || isempty(ct.numOfCtScen)
                return;
            end
            originalNumOfCtScen = ct.numOfCtScen;
            fields = fieldnames(ct);
            for fieldIx = 1:numel(fields)
                fieldName = fields{fieldIx};
                value = ct.(fieldName);
                if iscell(value) && isvector(value) && ...
                        numel(value) == originalNumOfCtScen
                    ct.(fieldName) = value(refCtScenId);
                end
            end
            ct.numOfCtScen = 1;
            ct.refScen = 1;
        end

        function cst = selectCst(cst,refCtScenId)
            if ~iscell(cst) || size(cst,2) < 4
                return;
            end
            cst = ...
                planWorkflow.precompute.CtReferenceDataView.selectCstColumn( ...
                cst,4,refCtScenId);
            if size(cst,2) >= 7
                cst = ...
                    planWorkflow.precompute.CtReferenceDataView.selectCstColumn( ...
                    cst,7,refCtScenId);
            end
        end

        function cst = selectCstColumn(cst,columnIx,refCtScenId)
            for rowIx = 1:size(cst,1)
                value = cst{rowIx,columnIx};
                if iscell(value) && numel(value) >= refCtScenId
                    cst{rowIx,columnIx} = value(refCtScenId);
                end
            end
        end
    end
end
