function result = transport(M, conn, varargin)
%TRANSPORT Compute combined transport using geometry and connection
%
%   result = bct.manifold.connection.transport(M, conn)
%   result = bct.manifold.connection.transport(M, conn, 'sign', 'minus')
%   result = bct.manifold.connection.transport(M, conn, 'sign', 'plus')
%
% Purpose
%   Combines geometric parallel transport (no-rotation transport) with
%   a connection 1-form to compute the total rotation angle when
%   transporting a direction field across edges on a surface.
%
% Inputs
%   M    - bct.Manifold object
%   conn - Connection structure (e.g., from bct.manifold.connection.trivial)
%          Must contain .trivialConnection field
%
% Name-Value Arguments
%   'sign' - 'minus' (default) or 'plus'
%            'minus': combined = geometric - connection (subtract)
%            'plus':  combined = geometric + connection (add)
%
% Outputs
%   result - Structure with fields:
%     .attributes         - Transport metadata
%     .combinedTransport  - Combined transport angles (struct with .value and .attributes)
%     .geometricTransport - Geometric transport (struct with .value and .attributes)
%     .connectionTransport - Connection 1-form (struct with .value and .attributes)
%
% Description
%   This function computes the total rotation when transporting a direction
%   field across edges, accounting for both:
%   1. Geometric transport (dTheta): Change due to surface curvature
%   2. Connection 1-form (phi): Additional rotation from the connection
%
%   The sign convention determines how these combine:
%   - 'minus': combined = geometric - connection (typical for trivial connections)
%   - 'plus':  combined = geometric + connection (alternative convention)
%
%   If a direction has angle α_i in face i, after transport to face j:
%     α_j = α_i + combinedTransport
%
% Algorithm
%   1. Extract connection 1-form from connection structure
%   2. Compute geometric transport from face tangent frames
%   3. Combine: combined = geometric ± connection (based on sign parameter)
%   4. Wrap result to (-π, π] for numerical stability
%
% Examples
%   % Compute trivial connection and combined transport
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   conn = bct.manifold.connection.trivial(M, ...
%       'singularities', [100, 500], 'weights', [1, 1]);
%   
%   %  Default: combined = geometric - connection
%   trans = bct.manifold.connection.transport(M, conn);
%   combined = trans.combinedTransport.value;  % [nH×1] combined transport
%   
%   % Alternative sign convention
%   trans = bct.manifold.connection.transport(M, conn, 'sign', 'plus');
%   combined = trans.combinedTransport.value;  % [nH×1] with plus sign
%
% See also: bct.manifold.geometry.face.transport, 
%           bct.manifold.connection.trivial

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.connection.transport';
addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
addRequired(p, 'conn', @isstruct);
addParameter(p, 'sign', 'minus', @(x) ismember(lower(string(x)), ["minus", "plus"]));
parse(p, M, conn, varargin{:});

signMode = lower(string(p.Results.sign));

% Validate connection structure
if ~isfield(conn, 'trivialConnection')
    error('bct:manifold:connection:transport:MissingField', ...
        'Connection structure must contain trivialConnection field');
end

% Extract trivialConnection from connection
connectionTransport = conn.trivialConnection.value;     % [nH×1]

% Get geometric transport (no-rotation transport from face tangent frames)
[geometricHeader, geometricTransport] = bct.manifold.geometry.face.transport(M);

% Validate dimensions
if numel(geometricTransport) ~= numel(connectionTransport)
    error('bct:manifold:connection:transport:DimensionMismatch', ...
        'geometricTransport [%d×1] and connectionTransport [%d×1] must have same length', ...
        numel(geometricTransport), numel(connectionTransport));
end

nH = numel(geometricTransport);

% Combine geometric transport with connection
switch signMode
    case "minus"
        combinedTransport = geometricTransport - connectionTransport;
        formula = 'combinedTransport = geometricTransport - connectionTransport';
    case "plus"
        combinedTransport = geometricTransport + connectionTransport;
        formula = 'combinedTransport = geometricTransport + connectionTransport';
    otherwise
        error('bct:manifold:connection:transport:UnknownSign', ...
            'Unknown sign mode: %s. Use ''minus'' or ''plus''.', signMode);
end

% Wrap to (-pi, pi] for numerical stability
combinedTransport = mod(combinedTransport + pi, 2*pi) - pi;

% Build output structure
result = struct();

% Top-level attributes
result.attributes = struct();
result.attributes.schema = 'bct.manifold.connection.transport@1.0.0';
result.attributes.type = 'combined_transport';
result.attributes.method = char(signMode);
result.attributes.formula = formula;
result.attributes.nHalfedges = nH;
result.attributes.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

% Dataset 1: combinedTransport (combined transport)
result.combinedTransport = struct();
result.combinedTransport.value = combinedTransport;
result.combinedTransport.attributes = struct();
result.combinedTransport.attributes.name = 'combinedTransport';
result.combinedTransport.attributes.path = 'connection/transport/combinedTransport';
result.combinedTransport.attributes.description = 'Combined transport: geometric + connection';
result.combinedTransport.attributes.shape = [nH, 1];
result.combinedTransport.attributes.dtype = class(combinedTransport);
result.combinedTransport.attributes.units = 'radians';
result.combinedTransport.attributes.support = 'halfedge';
result.combinedTransport.attributes.formula = formula;
result.combinedTransport.attributes.wrapping = '(-pi, pi]';

% Dataset 2: geometricTransport (geometric transport)
result.geometricTransport = struct();
result.geometricTransport.value = geometricTransport;
result.geometricTransport.attributes = geometricHeader;

% Dataset 3: connectionTransport (connection 1-form, from input)
result.connectionTransport = conn.trivialConnection;

end
