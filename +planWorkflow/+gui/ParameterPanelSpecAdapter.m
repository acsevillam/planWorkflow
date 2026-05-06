classdef ParameterPanelSpecAdapter
    % ParameterPanelSpecAdapter Converts workflow schema descriptors to GUI specs.

    methods (Static)
        function specs = fromSchema(schemaSpecs)
            specs = repmat( ...
                planWorkflow.gui.ParameterPanelSpecAdapter.spec('','',''), ...
                1,0);
            for specIx = 1:numel(schemaSpecs)
                helpText = '';
                if isfield(schemaSpecs(specIx),'helpKey') && ...
                        ~isempty(schemaSpecs(specIx).helpKey)
                    helpText = planWorkflow.gui.HelpText.parameter( ...
                        schemaSpecs(specIx).helpKey);
                end
	                specs(end + 1) = ...
	                    planWorkflow.gui.ParameterPanelSpecAdapter.spec( ...
	                    schemaSpecs(specIx).name, ...
	                    schemaSpecs(specIx).field, ...
	                    schemaSpecs(specIx).type,helpText, ...
	                    schemaSpecs(specIx).controlKind, ...
	                    schemaSpecs(specIx).optionsKey, ...
                        schemaSpecs(specIx).isConfigField); %#ok<AGROW>
	            end
	        end

	        function spec = spec(name,field,type,helpText,controlKind, ...
	                optionsKey,isConfigField)
	            if nargin < 4
	                helpText = '';
	            end
	            if nargin < 5 || isempty(controlKind)
	                controlKind = ...
	                    planWorkflow.gui.ParameterPanelSpecAdapter.defaultControlKind( ...
	                    type);
	            end
	            if nargin < 6 || isempty(optionsKey)
	                optionsKey = field;
	            end
                if nargin < 7 || isempty(isConfigField)
                    isConfigField = true;
                end
	            spec = struct('name',name,'field',field,'type',type, ...
	                'helpText',helpText,'controlKind',controlKind, ...
	                'optionsKey',optionsKey, ...
                    'isConfigField',logical(isConfigField));
	        end

	        function spec = section(name,field)
	            spec = planWorkflow.gui.ParameterPanelSpecAdapter.spec( ...
	                name,field,'section','','section');
	        end

	        function controlKind = defaultControlKind(type)
	            switch char(type)
	                case 'section'
	                    controlKind = 'section';
	                case 'logical'
	                    controlKind = 'checkbox';
	                case 'multiSelect'
	                    controlKind = 'multiSelect';
	                otherwise
	                    controlKind = 'edit';
	            end
	        end
	    end
	end
