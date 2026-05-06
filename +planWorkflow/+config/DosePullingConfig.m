classdef DosePullingConfig
    % DosePullingConfig Shared dose-pulling channel contract.

    methods (Static)
        function runConfig = validateActiveStartConfigs(template,runConfig)
            if ~isfield(template,'dosePulling') || ...
                    isempty(template.dosePulling)
                return;
            end

            channelNames = fieldnames(template.dosePulling);
            for i = 1:numel(channelNames)
                planWorkflow.config.DosePullingConfig.activeStartValue( ...
                    runConfig,template.dosePulling.(channelNames{i}), ...
                    channelNames{i});
            end
        end

        function tf = isChannelEnabled(runConfig,channelName)
            tf = false;
            enabledField = ...
                planWorkflow.config.DosePullingConfig.enabledFieldName( ...
                channelName);
            if ~isstruct(runConfig) || ~isfield(runConfig,enabledField)
                return;
            end

            value = runConfig.(enabledField);
            if isempty(value)
                return;
            end
            tf = planWorkflow.config.DosePullingConfig.logicalFlag( ...
                value,enabledField);
        end

        function value = activeStartValue(runConfig,channel,channelName)
            value = [];
            if ~planWorkflow.config.DosePullingConfig.isChannelEnabled( ...
                    runConfig,channelName)
                return;
            end

            startConfig = char(channel.startConfig);
            if ~isfield(runConfig,startConfig)
                error('planWorkflow:config:DosePullingConfig:MissingStartConfig', ...
                    ['runConfig does not define active dose pulling ' ...
                     'startConfig "%s" for channel "%s".'], ...
                    startConfig,channelName);
            end

            value = runConfig.(startConfig);
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
                error('planWorkflow:config:DosePullingConfig:InvalidStartConfig', ...
                    'runConfig.%s must be a finite numeric scalar.', ...
                    startConfig);
            end
        end

        function fieldName = enabledFieldName(channelName)
            fieldName = regexprep(char(channelName),'_(\d+)$','$1');
        end

        function tf = logicalFlag(value,fieldName)
            if islogical(value) && isscalar(value)
                tf = value;
                return;
            end
            if isnumeric(value) && isscalar(value) && isfinite(value) && ...
                    any(value == [0 1])
                tf = logical(value);
                return;
            end
            if ischar(value) || (isstring(value) && isscalar(value))
                text = lower(strtrim(char(value)));
                if any(strcmp(text,{'true','on','1','yes'}))
                    tf = true;
                    return;
                end
                if any(strcmp(text,{'false','off','0','no'}))
                    tf = false;
                    return;
                end
            end

            error('planWorkflow:config:DosePullingConfig:InvalidChannelFlag', ...
                ['runConfig.%s must be a logical scalar or one of ' ...
                 'true/false, on/off, 1/0, yes/no.'],fieldName);
        end
    end
end
