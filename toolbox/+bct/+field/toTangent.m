function result = toTangent(M, complexField, varargin)
%TOTANGENT Convert complex face-based field to 3D tangent vectors
%
% Syntax:
%   result = bct.field.toTangent(M, z)
%   result = bct.field.toTangent(M, z, 'Normalize', true)
%   result = bct.field.toTangent(M, z, 'MagnitudeThreshold', 0.1)
%
% Inputs:
%   M            - bct.Manifold object
%   complexField - [nF×1] Complex field in face tangent frame basis
%                  z = Re(z) * t1 + Im(z) * t2
%
% Name-Value Arguments:
%   Normalize           - true | false (default) - Normalize to unit vectors
%   MagnitudeThreshold  - Scalar threshold for normalization (default: 0)
%                         Only normalize where magnitude > threshold
%   MaskPercentile      - Keep top N% by magnitude (default: 100)
%                         Alternative to MagnitudeThreshold
%
% Outputs:
%   result - Structure with fields:
%     .vectors     - [nF×3] 3D tangent vectors on manifold
%     .magnitude   - [nF×1] Original magnitude (before normalization)
%     .mask        - [nF×1] logical mask of kept vectors
%     .normalized  - true/false indicating if normalization was applied
%
% Description:
%   Converts a complex-valued field defined in per-face tangent coordinate
%   systems (t1, t2) to explicit 3D tangent vectors embedded in ℝ³.
%   
%   The conversion is:
%     X = Re(z) * t1 + Im(z) * t2
%   
%   Where t1, t2 are orthonormal tangent frame vectors for each face.
%   
%   Optionally normalizes vectors where magnitude exceeds a threshold,
%   useful for direction field visualization.
%
% Examples:
%   % Basic conversion
%   result = bct.field.toTangent(M, z);
%   vectors = result.vectors;
%   
%   % Normalized direction field, keep top 20% by magnitude
%   result = bct.field.toTangent(M, z, 'Normalize', true, 'MaskPercentile', 20);
%   directions = result.vectors;  % Unit where mask=true, zero elsewhere
%   
%   % Threshold-based masking
%   result = bct.field.toTangent(M, z, 'Normalize', true, 'MagnitudeThreshold', 0.1);
%
% See also: bct.field.generate.vectorHeat, bct.field.direction,
%           bct.manifold.geometry.face

% ----------------------------
% Parse inputs
% ----------------------------
p = inputParser;
p.FunctionName = 'bct.field.toTangent';
p.addRequired('M', @(x) isa(x, 'bct.Manifold'));
p.addRequired('complexField', @(x) isnumeric(x) && ~isreal(x));
p.addParameter('Normalize', false, @islogical);
p.addParameter('MagnitudeThreshold', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
p.addParameter('MaskPercentile', 100, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 100);
p.parse(M, complexField, varargin{:});

z = double(complexField(:));
normalize = p.Results.Normalize;
magnitudeThreshold = p.Results.MagnitudeThreshold;
maskPercentile = p.Results.MaskPercentile;

% Validate input size
nF = size(M.Faces, 1);
if numel(z) ~= nF
    error('bct:field:toTangent:InvalidSize', ...
        'complexField must be [nF×1] = [%d×1], got [%d×1]', nF, numel(z));
end

% ----------------------------
% Get face tangent frames
% ----------------------------
geom = M.geometry();
t1 = double(geom.face.tangent1.value);  % [nF×3]
t2 = double(geom.face.tangent2.value);  % [nF×3]

% ----------------------------
% Convert to 3D tangent vectors
% ----------------------------
% X = Re(z) * t1 + Im(z) * t2
X = real(z) .* t1 + imag(z) .* t2;  % [nF×3]

% Compute magnitude
mag = abs(z);  % [nF×1]

% ----------------------------
% Apply magnitude-based masking
% ----------------------------
if maskPercentile < 100
    % Keep top N% by magnitude
    threshold = prctile(mag, 100 - maskPercentile);
    mask = (mag >= threshold) & (mag > 0);
else
    % Use explicit threshold
    mask = (mag >= magnitudeThreshold) & (mag > 0);
end

% ----------------------------
% Optionally normalize
% ----------------------------
Xout = X;
if normalize
    % Normalize only where mask is true
    Xout(mask, :) = X(mask, :) ./ mag(mask);
    % Zero out where mask is false
    Xout(~mask, :) = 0;
end

% ----------------------------
% Assemble output structure
% ----------------------------
result = struct();
result.vectors = Xout;
result.magnitude = mag;
result.mask = mask;
result.normalized = normalize;
result.magnitudeThreshold = magnitudeThreshold;
result.maskPercentile = maskPercentile;

end
