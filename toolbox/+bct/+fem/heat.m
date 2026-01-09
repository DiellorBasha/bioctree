function out = heat(FEM, signal, t, k)
%HEAT Heat evolution operator wrapper
%
% Syntax:
%   out = bct.fem.heat(FEM, signal, t, k)
%
% Thin wrapper for registry/runtime system.
% Delegates to FEM.heat() method.
%
% See also: bct.FEM.heat

arguments
    FEM    (1,1) bct.FEM
    signal (:,1) double
    t      (1,1) double
    k      (1,1) {mustBeInteger, mustBePositive}
end

out = FEM.heat(signal, t, k);

end
