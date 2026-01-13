function F = heat(varargin)
%HEAT Create heat kernel diffused field from point source
%
% Syntax:
%   F = bct.field.generate.heat(index, M, tau)
%   F = bct.field.generate.heat('Vertex', index, 'Manifold', M, 'Tau', tau)
%   F = bct.field.generate.heat('Face', index, 'Manifold', M, 'Tau', tau)
%
% Short Form (Positional Arguments):
%   index - Source location index (vertex/face/edge number)
%   M     - bct.Manifold object
%   tau   - Heat kernel time parameter (controls diffusion width)
%
%   Optional after tau:
%   'Support'   - Support type: 'vertex' (default), 'face', 'edge'
%   'NumModes'  - Number of eigenmodes (default: min(100, Nv))
%
% Long Form (Name-Value Arguments):
%   'Vertex'    - Vertex index (implies support='vertex')
%   'Face'      - Face index (implies support='face')  
%   'Edge'      - Edge index (implies support='edge')
%   'Manifold'  - bct.Manifold object (required)
%   'Tau'       - Heat kernel time parameter (required)
%   'Support'   - Support type (alternative to Vertex/Face/Edge)
%   'Index'     - Generic index (requires explicit Support)
%   'NumModes'  - Number of eigenmodes for spectral approximation
%   'Normalize' - Normalize output to [0,1] (default: true)
%
% Outputs:
%   F - Field struct conforming to bct.field.schema
%       Heat kernel diffused from source location
%
% Description:
%   Creates a smooth field by diffusing heat from a point source using
%   spectral methods:
%   
%   1. Creates delta field at source using bct.field.generate.delta
%   2. Gets FEM representation and computes eigenpairs (cached)
%   3. Projects delta to spectral domain via eigenmodes
%   4. Applies heat kernel: exp(-lambda * tau) to each mode
%   5. Reconstructs back to spatial domain
%   
%   The tau parameter controls diffusion distance:
%   - Small tau (e.g., 1-10) → localized near source
%   - Medium tau (e.g., 10-100) → moderate spread
%   - Large tau (e.g., 100-1000) → global smooth field
%   
%   This is the fundamental Green's function for the heat equation
%   on the manifold and provides geodesically-aware smooth fields.
%
% Examples:
%   % Short form: Heat from vertex 4 with tau=10
%   F = bct.field.generate.heat(4, M, 10);
%
%   % Short form with face support
%   F = bct.field.generate.heat(50, M, 20, 'Support', 'face');
%
%   % Long form: Heat from vertex 23
%   F = bct.field.generate.heat('Vertex', 23, 'Manifold', M, 'Tau', 15);
%
%   % Control eigenmode count for accuracy
%   F = bct.field.generate.heat(10, M, 50, 'NumModes', 200);
%
%   % Wrap in Field class
%   s = bct.field.generate.heat(100, M, 25);
%   F = bct.Field.fromStruct(s);
%
%   % Compare different tau values
%   F1 = bct.field.generate.heat(1, M, 5);   % Localized
%   F2 = bct.field.generate.heat(1, M, 50);  % Medium spread
%   F3 = bct.field.generate.heat(1, M, 200); % Global smooth
%
% See also: bct.field.generate.delta, bct.kernel.dictionary, 
%           bct.brush.patch.spectral

% Parse inputs - detect short vs long form
if nargin >= 3 && isa(varargin{2}, 'bct.Manifold') && isnumeric(varargin{3})
    % Short form: heat(index, M, tau, ...)
    options = parseShortForm(varargin{:});
else
    % Long form: heat('Vertex', val, 'Manifold', M, 'Tau', tau, ...)
    options = parseLongForm(varargin{:});
end

% Generate heat field
F = generateHeat(options);

% Validate output
bct.field.validate(F);

end

%% ========================================================================
% HEAT FIELD GENERATOR
%% ========================================================================

function F = generateHeat(options)
%GENERATEHEAT Create heat kernel diffused field using spectral methods

M = options.Manifold;
support = options.Support;
index = options.Index;
tau = options.Tau;
numModes = options.NumModes;
normalize = options.Normalize;

% Step 1: Create delta field at source location
% Use the existing delta generator
delta_struct = bct.field.generate.delta(index, M, 'Support', support);
delta_values = delta_struct.value;

% Step 2: Get eigenpairs from Manifold
% Uses internal caching
if isempty(numModes)
    Nv = M.numVertices();
    numModes = min(100, Nv);
end

% Get eigenpairs (uses caching internally)
E = M.eigenmodes(numModes);
eigenvalues = E.Values;

% Step 3: Create mass-weighted delta (for vertex support)
% For vertex fields, we need M^(-1) * delta for proper projection
if strcmp(support, 'vertex')
    Mass = M.DEC().hodge0;  % Get mass matrix from DEC
    delta_fem = Mass \ delta_values;
else
    % For face/edge support, use values directly
    % (FEM eigenpairs are vertex-based, so this is an approximation)
    delta_fem = delta_values;
end

% Step 4: Project to spectral domain using Eigenpairs
spectral_coeffs = E.project(delta_fem);

% Step 5: Build heat kernel: exp(-lambda * tau)
heat_kernel = exp(-eigenvalues * tau);

% Step 6: Apply kernel in spectral domain
filtered_coeffs = spectral_coeffs .* heat_kernel;

% Step 7: Reconstruct to spatial domain using Eigenpairs
heat_values = E.reconstruct(filtered_coeffs);

% Step 8: Normalize if requested
if normalize
    heat_values = heat_values - min(heat_values);
    if max(heat_values) > 0
        heat_values = heat_values / max(heat_values);
    end
end

% Step 9: Handle support mismatch
% Eigenpairs are always vertex-based, so we have vertex values
% If requested support is different, we need to transfer
if strcmp(support, 'face')
    % Average from vertices to faces
    heat_values = transferVertexToFace(M, heat_values);
elseif strcmp(support, 'edge')
    % Average from vertices to edges
    heat_values = transferVertexToEdge(M, heat_values);
end
% Otherwise support='vertex' and we're done

% Build field struct
F = struct();
F.schemaVersion = 'bct.field@1';
F.meshId = char(M.ID);
F.support = char(support);
F.valueType = 'scalar';
F.value = heat_values;
F.meta = struct(...
    'generator', 'heat', ...
    'index', index, ...
    'support', char(support), ...
    'tau', tau, ...
    'numModes', numModes, ...
    'normalized', normalize);

end

%% ========================================================================
% SUPPORT TRANSFER FUNCTIONS
%% ========================================================================

function faceValues = transferVertexToFace(M, vertexValues)
%TRANSFERVERTEXTOFACE Average vertex values to face centers

F = M.Faces;
Nf = size(F, 1);
faceValues = zeros(Nf, 1);

for i = 1:Nf
    % Average values at three vertices of face
    faceValues(i) = mean(vertexValues(F(i, :)));
end

end

function edgeValues = transferVertexToEdge(M, vertexValues)
%TRANSFERVERTEXTOEDGE Average vertex values to edge midpoints

E = M.Edges;
Ne = size(E, 1);
edgeValues = zeros(Ne, 1);

for i = 1:Ne
    % Average values at two endpoints of edge
    edgeValues(i) = mean(vertexValues(E(i, :)));
end

end

%% ========================================================================
% ARGUMENT PARSING
%% ========================================================================

function options = parseShortForm(index, M, tau, varargin)
%PARSESHORTFORM Parse short form: heat(index, M, tau, ...)

% Validate positional arguments
if ~isnumeric(index) || ~isscalar(index) || index <= 0 || mod(index, 1) ~= 0
    error('bct:field:generate:heat:InvalidIndex', ...
        'First argument must be positive integer index');
end

if ~isa(M, 'bct.Manifold')
    error('bct:field:generate:heat:InvalidManifold', ...
        'Second argument must be bct.Manifold object');
end

if ~isnumeric(tau) || ~isscalar(tau) || tau <= 0
    error('bct:field:generate:heat:InvalidTau', ...
        'Third argument (tau) must be positive number');
end

% Parse optional name-value pairs after tau
p = inputParser();
p.addParameter('Support', 'vertex', @(x) ischar(x) || isstring(x));
p.addParameter('NumModes', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Normalize', true, @islogical);
p.parse(varargin{:});

% Build options struct
options = struct();
options.Manifold = M;
options.Index = index;
options.Tau = tau;
options.Support = string(p.Results.Support);
options.NumModes = p.Results.NumModes;
options.Normalize = p.Results.Normalize;

end

function options = parseLongForm(varargin)
%PARSELONGFORM Parse long form: heat('Vertex', val, 'Manifold', M, 'Tau', tau, ...)

p = inputParser();
p.addParameter('Manifold', [], @(x) isa(x, 'bct.Manifold'));
p.addParameter('Tau', [], @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('Vertex', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Face', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Edge', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Index', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Support', '', @(x) ischar(x) || isstring(x));
p.addParameter('NumModes', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Normalize', true, @islogical);
p.parse(varargin{:});

r = p.Results;

% Validate required arguments
if isempty(r.Manifold)
    error('bct:field:generate:heat:MissingManifold', ...
        'Manifold must be specified');
end

if isempty(r.Tau)
    error('bct:field:generate:heat:MissingTau', ...
        'Tau parameter must be specified');
end

% Resolve support and index (reuse logic from delta)
[support, index] = resolveLocationArgs(r);

% Build options struct
options = struct();
options.Manifold = r.Manifold;
options.Tau = r.Tau;
options.Support = support;
options.Index = index;
options.NumModes = r.NumModes;
options.Normalize = r.Normalize;

end

function [support, index] = resolveLocationArgs(r)
%RESOLVELOCATIONARGS Resolve support type and index from arguments

% Count how many location arguments are provided
locationArgs = {r.Vertex, r.Face, r.Edge, r.Index};
providedArgs = ~cellfun(@isempty, locationArgs);
numProvided = sum(providedArgs);

if numProvided == 0
    % Default: vertex 1
    support = "vertex";
    index = 1;
    
elseif numProvided > 1
    error('bct:field:generate:heat:AmbiguousLocation', ...
        'Only one of Vertex, Face, Edge, or Index can be specified');
    
else
    % Determine support and index from provided argument
    if ~isempty(r.Vertex)
        support = "vertex";
        index = r.Vertex;
    elseif ~isempty(r.Face)
        support = "face";
        index = r.Face;
    elseif ~isempty(r.Edge)
        support = "edge";
        index = r.Edge;
    else  % r.Index
        % Use Index with explicit Support parameter
        index = r.Index;
        if isempty(r.Support)
            error('bct:field:generate:heat:MissingSupport', ...
                'When using Index parameter, Support must be specified');
        end
        support = string(r.Support);
    end
end

% Validate index
if index <= 0 || mod(index, 1) ~= 0
    error('bct:field:generate:heat:InvalidIndex', ...
        'Index must be positive integer');
end

end
