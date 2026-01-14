function u = unitFromLexp(Lexp)
%UNITFROMLEXP Generate SI unit label from length dimension exponent
%
% Syntax:
%   u = bct.manifold.metric.unitFromLexp(Lexp)
%
% Inputs:
%   Lexp - Length dimension exponent (integer)
%
% Outputs:
%   u - SI unit label string
%
% Description:
%   Generates canonical SI unit labels for length-dimension quantities:
%   - Lexp = +2 → "m^2"  (area)
%   - Lexp = +1 → "m"    (length)
%   - Lexp =  0 → "1"    (dimensionless)
%   - Lexp = -1 → "1/m"  (wavenumber, gradient)
%   - Lexp = -2 → "1/m^2" (curvature, Laplacian eigenvalues)
%
% Examples:
%   u = bct.manifold.metric.unitFromLexp(2);   % "m^2"
%   u = bct.manifold.metric.unitFromLexp(-1);  % "1/m"
%   u = bct.manifold.metric.unitFromLexp(0);   % "1"
%
% See also: bct.manifold.metric.quantity, bct.manifold.metric.spec

arguments
    Lexp (1,1) {mustBeInteger}
end

switch Lexp
    case 2
        u = "m^2";
    case 1
        u = "m";
    case 0
        u = "1";
    case -1
        u = "1/m";
    case -2
        u = "1/m^2";
    otherwise
        error('bct:manifold:metric:UnsupportedLexp', ...
            'Length exponent %d not supported. Use: -2, -1, 0, +1, +2', Lexp);
end

end
