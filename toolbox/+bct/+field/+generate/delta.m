function F = delta(varargin)
%DELTA Create Kronecker delta field (impulse at single location)
%
% Syntax:
%   F = bct.field.generate.delta(index, M)
%   F = bct.field.generate.delta('Vertex', index, 'Manifold', M)
%   F = bct.field.generate.delta('Face', index, 'Manifold', M)
%   F = bct.field.generate.delta('Edge', index, 'Manifold', M)
%
% Short Form (Positional Arguments):
%   index - Location index (vertex/face/edge number)
%   M     - bct.Manifold object
%
%   Optional after manifold:
%   'Support'  - Support type: 'vertex' (default), 'face', 'edge'
%   'Annotate' - Add metric annotation (default: false)
%
% Long Form (Name-Value Arguments):
%   'Vertex'   - Vertex index (implies support='vertex')
%   'Face'     - Face index (implies support='face')
%   'Edge'     - Edge index (implies support='edge')
%   'Manifold' - bct.Manifold object (required)
%   'Support'  - Support type (alternative to Vertex/Face/Edge)
%   'Index'    - Generic index (requires explicit Support)
%   'Annotate' - Add metric annotation (default: false)
%
% Outputs:
%   F - Field struct conforming to bct.field.schema
%       Contains zeros everywhere except 1.0 at specified location
%
% Description:
%   Creates a Kronecker delta field - an impulse at a single location.
%   This is useful for:
%   - Testing differential operators (gradient, divergence)
%   - Green's function analysis
%   - Heat kernel visualization
%   - Geodesic distance computation
%   - Response function studies
%
%   The Annotate parameter controls whether to add metric information.
%   When false (default), returns bare numerical field.
%   When true, adds metric via bct.field.annotate().
%
% Examples:
%   % Short form: Delta at vertex 4
%   F = bct.field.generate.delta(4, M);
%
%   % Short form: Delta at face 50
%   F = bct.field.generate.delta(50, M, 'Support', 'face');
%
%   % Long form: Delta at vertex 23 with annotation
%   F = bct.field.generate.delta('Vertex', 23, 'Manifold', M, 'Annotate', true);
%
%   % Long form: Delta at edge 100
%   F = bct.field.generate.delta('Edge', 100, 'Manifold', M);
%
%   % Wrap in Field class
%   s = bct.field.generate.delta(10, M);
%   F = bct.Field.fromStruct(s);
%
% See also: bct.field.make, bct.field.infer, bct.Manifold

% Parse inputs - detect short vs long form
if nargin >= 2 && isa(varargin{2}, 'bct.Manifold')
    % Short form: delta(index, M, ...)
    options = parseShortForm(varargin{:});
else
    % Long form: delta('Vertex', val, 'Manifold', M, ...)
    options = parseLongForm(varargin{:});
end

% Generate delta field
F = generateDelta(options);

% Optionally annotate with metric
if options.Annotate
    F = bct.field.annotate(F);
end

% Validate output
bct.field.validate(F);

end

%% ========================================================================
% DELTA FIELD GENERATOR
%% ========================================================================

function F = generateDelta(options)
%GENERATEDELTA Create Kronecker delta field

M = options.Manifold;
support = options.Support;
index = options.Index;

% Get support size
n = bct.field.sizeOfSupport(support, M);

% Validate index
if index < 1 || index > n
    error('bct:field:generate:delta:InvalidIndex', ...
        'Index %d out of range for %s support (1-%d)', ...
        index, support, n);
end

% Create delta field (zeros with 1 at index)
value = zeros(n, 1);
value(index) = 1.0;

% Build field struct
F = struct();
F.schemaVersion = 'bct.field@1';
F.meshId = char(M.ID);
F.support = char(support);
F.valueType = 'scalar';
F.value = value;
F.meta = struct('generator', 'delta', 'index', index, 'support', char(support));

end

%% ========================================================================
% ARGUMENT PARSING
%% ========================================================================

function options = parseShortForm(index, M, varargin)
%PARSESHORTFORM Parse short form: delta(index, M, ...)

% Validate positional arguments
if ~isnumeric(index) || ~isscalar(index) || index <= 0 || mod(index, 1) ~= 0
    error('bct:field:generate:delta:InvalidIndex', ...
        'First argument must be positive integer index');
end

if ~isa(M, 'bct.Manifold')
    error('bct:field:generate:delta:InvalidManifold', ...
        'Second argument must be bct.Manifold object');
end

% Parse optional name-value pairs after manifold
p = inputParser();
p.addParameter('Support', 'vertex', @(x) ischar(x) || isstring(x));
p.addParameter('Annotate', false, @islogical);
p.parse(varargin{:});

% Build options struct
options = struct();
options.Manifold = M;
options.Index = index;
options.Support = string(p.Results.Support);
options.Annotate = p.Results.Annotate;

end

function options = parseLongForm(varargin)
%PARSELONGFORM Parse long form: delta('Vertex', val, 'Manifold', M, ...)

p = inputParser();
p.addParameter('Manifold', [], @(x) isa(x, 'bct.Manifold'));
p.addParameter('Vertex', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Face', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Edge', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Index', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
p.addParameter('Support', '', @(x) ischar(x) || isstring(x));
p.addParameter('Annotate', false, @islogical);
p.parse(varargin{:});

r = p.Results;

% Validate required arguments
if isempty(r.Manifold)
    error('bct:field:generate:delta:MissingManifold', ...
        'Manifold must be specified');
end

% Resolve support and index
[support, index] = resolveLocationArgs(r);

% Build options struct
options = struct();
options.Manifold = r.Manifold;
options.Support = support;
options.Index = index;
options.Annotate = r.Annotate;

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
    error('bct:field:generate:delta:AmbiguousLocation', ...
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
            error('bct:field:generate:delta:MissingSupport', ...
                'When using Index parameter, Support must be specified');
        end
        support = string(r.Support);
    end
end

% Validate index
if index <= 0 || mod(index, 1) ~= 0
    error('bct:field:generate:delta:InvalidIndex', ...
        'Index must be positive integer');
end

end
