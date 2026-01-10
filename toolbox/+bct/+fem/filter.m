function out = filter(FEM, signal, kernel, k)
%FILTER Spectral filter operator wrapper
%
% Syntax:
%   out = bct.fem.filter(FEM, signal, kernel, k)
%
% Thin wrapper for registry/runtime system.
% Delegates to FEM.filter() method.
%
% See also: bct.FEM.filter

arguments
    FEM    (1,1) bct.FEM
    signal (:,1) double
    kernel % function_handle or vector
    k      (1,1) {mustBeInteger, mustBePositive}
end

out = FEM.filter(signal, kernel, k);

end
