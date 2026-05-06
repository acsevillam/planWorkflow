classdef BeamApplicator
    % BeamApplicator Applies template beam sets to matRad plan structs.

    methods (Static)
        function pln = apply(runConfig,pln,ct,cst,beamSet)
            pln.radiationMode = char(runConfig.radiationMode);
            pln.numOfFractions = beamSet.numOfFractions;
            pln.propStf.gantryAngles = beamSet.gantryAngles(:)';
            if isfield(beamSet,'couchAngles') && ~isempty(beamSet.couchAngles)
                pln.propStf.couchAngles = beamSet.couchAngles(:)';
            else
                pln.propStf.couchAngles = zeros( ...
                    1,numel(pln.propStf.gantryAngles));
            end
            pln.propStf.bixelWidth = beamSet.bixelWidth;
            pln.propStf.numOfBeams = numel(pln.propStf.gantryAngles);
            pln.propStf.isoCenter = ones(pln.propStf.numOfBeams,1) * ...
                matRad_getIsoCenter(cst,ct,0);
        end
    end
end
