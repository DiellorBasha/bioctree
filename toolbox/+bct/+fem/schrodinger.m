function out = schrodinger(FEM, signal, t, k)
%SCHRODINGER Schrödinger evolution operator wrapper
%
% Syntax:
%   out = bct.fem.schrodinger(FEM, signal, t, k)
%
% Thin wrapper for registry/runtime system.
% Delegates to FEM.schrodinger() method.
%
% See also: bct.FEM.schrodinger

arguments
    FEM    (1,1) bct.FEM
    signal (:,1) double
    t      (1,1) double
    k      (1,1) {mustBeInteger, mustBePositive}
end

out = FEM.schrodinger(signal, t, k);

end
