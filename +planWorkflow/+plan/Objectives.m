classdef Objectives
    % Objectives Objective helpers that are independent of workflow state.

    methods (Static)
        function [cst,ixRing1,ixRing2] = addDefaultRings(cst,ct,ixTarget,ixBody)
            vInnerMargin = struct('x',0,'y',0,'z',0);
            vOuterMargin = struct('x',20,'y',20,'z',20);
            metadata = struct('name','RING 0 - 20 mm','type','OAR', ...
                'visibleColor',[0,1,0.501960784313726]);
            [cst,ixRing1] = matRad_createRing(ixTarget,ixBody,cst,ct, ...
                vOuterMargin,vInnerMargin,metadata);

            vInnerMargin = struct('x',20,'y',20,'z',20);
            vOuterMargin = struct('x',50,'y',50,'z',50);
            metadata = struct('name','RING 20 - 50 mm','type','OAR', ...
                'visibleColor',[0,1,0.501960784313726]);
            [cst,ixRing2] = matRad_createRing(ixTarget,ixBody,cst,ct, ...
                vOuterMargin,vInnerMargin,metadata);
        end

        function cst = applyDefaultRingObjectives(cst,ixRing1,ixRing2,p)
            cst{ixRing1,5}.Priority = 4;
            cst{ixRing1,6}{1} = struct(DoseObjectives.matRad_MaxDVH(100,p * 1.10,0));
            cst{ixRing1,6}{1}.robustness = 'none';
            cst{ixRing1,6}{1}.dosePulling = false;

            cst{ixRing2,5}.Priority = 4;
            cst{ixRing2,6}{1} = struct(DoseObjectives.matRad_MaxDVH(100,p * 1.00,0));
            cst{ixRing2,6}{1}.robustness = 'none';
            cst{ixRing2,6}{1}.dosePulling = false;
        end
    end
end
