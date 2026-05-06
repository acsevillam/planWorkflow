classdef TemplateMutator
    % TemplateMutator Applies controlled mutations to resolved templates.

    methods (Static)
        function template = setObjectiveSet( ...
                template,objectiveSetName,objectiveSet)
            objectiveSetName = char(objectiveSetName);
            if strcmp(objectiveSetName,'reference')
                template.objectiveSets.reference = objectiveSet;
                return;
            end

            robustPlans = ...
                planWorkflow.templates.TemplateResolver.robustObjectiveSets( ...
                template);
            planIx = planWorkflow.templates.TemplateResolver.findTextField( ...
                robustPlans,'id',objectiveSetName);
            if planIx == 0
                error('planWorkflow:templates:PlanTemplate:UnknownObjectiveSet', ...
                    'Plan template "%s" does not define objective set "%s".', ...
                    char(template.id),objectiveSetName);
            end
            objectiveSet.id = robustPlans(planIx).id;
            objectiveSet.label = robustPlans(planIx).label;
            robustPlans(planIx) = objectiveSet;
            template.objectiveSets.robustPlans = robustPlans;
        end
    end
end
