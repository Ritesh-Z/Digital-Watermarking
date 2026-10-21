function cfg = defaultAttackSettings()
% DEFAULTATTACKSETTINGS  The noise strengths used in the project (paper values).
%
% PIPELINE:  STEP 6 (attacks). One place for these numbers, used by the
%            alpha search (fitnessFunction), attackAndExtract and the GUI.
%
%   gaussVar          variance of the Gaussian noise (image scaled to 0..1)
%   saltPepperDensity fraction of pixels turned black or white
%   speckleVar        variance of the multiplicative speckle noise
%   (shot / Poisson noise has no setting: its strength depends on the image)

    cfg = struct('gaussVar', 0.01, 'saltPepperDensity', 0.05, 'speckleVar', 0.04);
end
