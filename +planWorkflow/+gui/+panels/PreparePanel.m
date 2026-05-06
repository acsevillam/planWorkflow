classdef PreparePanel
    % PreparePanel Shared layout helpers for prepare/template editing.

    methods (Static)
        function values = supportedStructureRoles()
            values = {'OAR','TARGET'};
        end

        function layout = objectiveHeaderLayout()
            layout = struct();
            labelY = 0.895;
            labelHeight = 0.035;
            inputY = 0.875;
            inputHeight = 0.065;
            buttonY = 0.87;
            buttonHeight = 0.08;

            layout.prescriptionLabel = [0.03 labelY 0.12 labelHeight];
            layout.prescriptionEdit = [0.15 inputY 0.08 inputHeight];
            layout.fractionsLabel = [0.27 labelY 0.08 labelHeight];
            layout.fractionsEdit = [0.35 inputY 0.06 inputHeight];
            layout.addRobustPlanButton = [0.46 buttonY 0.12 buttonHeight];
            layout.deleteRobustPlanButton = [0.59 buttonY 0.12 buttonHeight];
            layout.addObjectiveButton = [0.72 buttonY 0.12 buttonHeight];
            layout.deleteObjectiveButton = [0.85 buttonY 0.12 buttonHeight];
            layout.objectiveTabsTop = 0.84;
        end

        function text = objectiveHelpTextForDisplay(topic)
            text = planWorkflow.gui.TextLayout.helpTextForDisplay( ...
                planWorkflow.gui.HelpText.objective(topic), ...
                planWorkflow.gui.TextLayout.objectiveHelpTextWrapColumn());
        end

    end
end
