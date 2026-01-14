function [header, Fout] = flip(meshInput, varargin)
%FLIP Flip face orientation to ensure normals point outward
%
% Syntax:
%   [header, Fout] = bct.manifold.geometry.face.flip(M)
%   [header, Fout] = bct.manifold.geometry.face.flip(V, F)
%
% Inputs:
%   M    - bct.Manifold object
%   OR
%   V    - [Nv×3] vertex coordinates
%   F    - [Nf×3] face connectivity (1-indexed)
%
% Outputs:
%   header - Structure containing:
%            .signedVolumeBefore - Signed volume before flipping
%            .signedVolumeAfter  - Signed volume after flipping (always positive)
%            .flippedAllFaces    - Boolean indicating if faces were flipped
%   Fout - [Nf×3] face connectivity with corrected orientation
%
% Description:
%   Determines if a mesh's face normals point outward by computing the signed
%   volume. If the signed volume is negative, the normals point inward, and
%   all faces are flipped by swapping columns 2 and 3.
%
%   The signed volume is computed as: sum(dot(a, cross(b, c))) / 6
%   where a, b, c are the vertices of each triangle.
%
% Examples:
%   % Flip face orientation from Manifold object
%   M = bct.Manifold(V, F);
%   [header, F_corrected] = bct.manifold.geometry.face.flip(M);
%   if header.flippedAllFaces
%       disp('Faces were flipped to point outward');
%   end
%
%   % Flip face orientation from V, F directly
%   [header, F_corrected] = bct.manifold.geometry.face.flip(V, F);
%
%   % Create new Manifold with corrected orientation
%   M_corrected = bct.Manifold(V, F_corrected);
%
% See also: bct.manifold.geometry.face.normals, bct.Manifold.flip

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:manifold:geometry:face:flip:NoInput', ...
        'At least one input required: flip(M) or flip(V, F)');
end

% Handle Manifold object or (V, F) inputs
if isa(meshInput, 'bct.Manifold')
    % Manifold interface: flip(M)
    V = meshInput.Vertices;
    F = meshInput.Faces;
elseif nargin >= 2
    % Direct interface: flip(V, F)
    V = meshInput;
    F = varargin{1};
else
    error('bct:manifold:geometry:face:flip:InvalidInput', ...
        'Usage: flip(M) or flip(V, F)');
end

% ----------------------------
% Compute signed volume
% ----------------------------
a = V(F(:,1), :);
b = V(F(:,2), :);
c = V(F(:,3), :);

signedVol = sum(dot(a, cross(b, c, 2), 2)) / 6;

% ----------------------------
% Flip faces if needed
% ----------------------------
Fout = F;
flipped = false;

if signedVol < 0
    % Negative volume means normals point inward - flip all faces
    Fout(:, [2 3]) = Fout(:, [3 2]);
    flipped = true;
    signedVolAfter = -signedVol;
else
    % Positive volume means normals already point outward
    signedVolAfter = signedVol;
end

% ----------------------------
% Package output
% ----------------------------
header = struct( ...
    'signedVolumeBefore', signedVol, ...
    'signedVolumeAfter',  signedVolAfter, ...
    'flippedAllFaces',    flipped ...
);

end