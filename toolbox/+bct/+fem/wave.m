function out = wave(FEM, signal, t, k)
%WAVE Wave evolution operator wrapper
%
% Syntax:
%   out = bct.fem.wave(FEM, signal, t, k)
%
% Thin wrapper for registry/runtime system.
% Delegates to FEM.wave() method.
%
% See also: bct.FEM.wave

arguments
    FEM    (1,1) bct.FEM
    signal (:,1) double
    t      (1,1) double
    k      (1,1) {mustBeInteger, mustBePositive}
end

out = FEM.wave(signal, t, k);

end
