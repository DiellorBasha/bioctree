function mesh = normalizeInput(varargin)
%NORMALIZEINPUT Parse and validate input for health checks.
%
%   mesh = normalizeInput(M)
%   mesh = normalizeInput(F)
%   mesh = normalizeInput(V, F)
%   mesh = normalizeInput({V, F})
%
% Inputs
%   M      : bct.Manifold object
%   F      : #F x 3 face connectivity matrix
%   V      : #V x 3 vertex coordinates
%   {V, F} : cell array with vertices and faces
%
% Output
%   mesh : struct with fields
%     .V     : vertex coordinates (empty if not provided)
%     .F     : face connectivity
%     .nV    : number of vertices (0 if V not provided, max(F(:)) otherwise)
%     .nF    : number of faces
%     .hasV  : logical, true if V was provided
%
% See also: bct.manifold.health.check

% Parse inputs
if nargin == 0
    error('bct:manifold:health:normalizeInput:NoInput', ...
        'At least one input argument required');
elseif nargin == 1
    arg = varargin{1};
    
    if isa(arg, 'bct.Manifold')
        % Manifold object
        V = arg.Vertices;
        F = arg.Faces;
        hasV = true;
    elseif iscell(arg) && numel(arg) == 2
        % {V, F} cell array
        V = arg{1};
        F = arg{2};
        hasV = true;
    elseif isnumeric(arg) && size(arg, 2) == 3
        % F only
        V = [];
        F = arg;
        hasV = false;
    else
        error('bct:manifold:health:normalizeInput:InvalidInput', ...
            'Single input must be bct.Manifold, {V,F} cell, or F matrix');
    end
    
elseif nargin == 2
    % V, F separate arguments
    V = varargin{1};
    F = varargin{2};
    hasV = true;
else
    error('bct:manifold:health:normalizeInput:TooManyInputs', ...
        'Expected 1 or 2 inputs');
end

% Validate F
if isempty(F)
    nF = 0;
    nV = 0;
elseif ~isnumeric(F) || size(F, 2) ~= 3
    error('bct:manifold:health:normalizeInput:InvalidFaces', ...
        'Faces must be numeric M×3 matrix');
else
    nF = size(F, 1);
    
    % Determine nV
    if hasV && ~isempty(V)
        if ~isnumeric(V) || size(V, 2) < 3
            error('bct:manifold:health:normalizeInput:InvalidVertices', ...
                'Vertices must be numeric M×3 (or M×d) matrix');
        end
        nV = size(V, 1);
    else
        % Infer from F
        if nF > 0
            nV = max(F(:));
        else
            nV = 0;
        end
        V = [];
        hasV = false;
    end
end

% Build output struct
mesh = struct( ...
    'V', V, ...
    'F', F, ...
    'nV', nV, ...
    'nF', nF, ...
    'hasV', hasV ...
);

end
