function conn = connection(M, varargin)
%CONNECTION Compute connections on manifolds
%
% Syntax:
%   conn = bct.manifold.connection(M, type, ...)
%
% Inputs:
%   M    - bct.Manifold object
%   type - Connection type: 'trivial' (default)
%
% Name-Value Arguments (for 'trivial' type):
%   'singularities' - Vertex indices where singularities are placed
%   'weights'       - Weights for each singularity (default: all 1)
%
% Outputs:
%   conn - Connection structure with type-specific fields
%     For 'trivial': 
%       .trivialConnection - Halfedge 1-form
%       .connectionEdge - Edge 1-form
%       .scalarPotential - Scalar potential β
%       .singularityVector - Singularity weights
%       .transport - Full transport structure (from bct.manifold.connection.transport)
%       .combinedTransport - Combined transport (convenience access)
%       .geometricTransport - Geometric transport (convenience access)
%       .connectionTransport - Connection transport (convenience access)
%
% Description:
%   Aggregator function for computing various types of connections on
%   triangulated surfaces. Currently supports:
%
%   TRIVIAL - Coexact connection from singularities
%     Solves: Δβ = -K + 2π*s
%     Returns: .trivialConnection, .connectionEdge, .scalarPotential, .singularityVector
%
%   TRANSPORT - Combined geometric and connection transport
%     Combines: geometric transport with connection 1-form
%     Returns: .combinedTransport, .geometricTransport, .connectionTransport
%     See: bct.manifold.connection.transport
%
% Examples:
%   % Trivial connection with two singularities
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   conn = bct.manifold.connection(M, 'trivial', ...
%       'singularities', [6653, 978], 'weights', [1, 1]);
%   
%   % Access connection 1-form
%   connectionEdge = conn.connectionEdge.value;
%   trivialConn = conn.trivialConnection.value;
%   
%   % Access combined transport (automatically computed)
%   combined = conn.combinedTransport.value;
%   
%   % Or access full transport structure
%   geometricTransport = conn.transport.geometricTransport.value;
%   
%   % Default type is trivial
%   conn = bct.manifold.connection(M, ...
%       'singularities', [100, 500]);
%
% See also: bct.manifold.connection.trivial, bct.manifold.connection.transport

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.connection';
p.KeepUnmatched = true;
addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));

% Check if first argument is a valid connection type
validTypes = ["trivial"];
if ~isempty(varargin) && (ischar(varargin{1}) || isstring(varargin{1})) && ...
        ismember(string(varargin{1}), validTypes)
    % First argument IS a connection type - parse normally
    addOptional(p, 'type', 'trivial', @(x) ischar(x) || isstring(x));
    parse(p, M, varargin{:});
    connType = string(p.Results.type);
    remainingArgs = struct2cell(p.Unmatched);
    remainingNames = fieldnames(p.Unmatched);
else
    % First argument is NOT a connection type - default to 'trivial'
    % All varargin are name-value pairs for the connection
    connType = "trivial";
    parse(p, M);  % Just parse M
    
    % Manually build name-value pairs from varargin
    if mod(numel(varargin), 2) ~= 0
        error('bct:manifold:connection:InvalidArgs', ...
            'Name-value arguments must come in pairs');
    end
    remainingNames = varargin(1:2:end);
    remainingArgs = varargin(2:2:end);
end

nameValuePairs = [remainingNames(:)'; remainingArgs(:)'];
nameValuePairs = nameValuePairs(:)';

% Dispatch to appropriate connection function
switch lower(connType)
    case 'trivial'
        conn = bct.manifold.connection.trivial(M, nameValuePairs{:});
        
        % Automatically compute and include transport
        trans = bct.manifold.connection.transport(M, conn);
        
        % Merge transport structure into connection
        % Top-level fields from transport
        conn.transport = trans;
        
        % Convenience access to combined transport
        conn.combinedTransport = trans.combinedTransport;
        conn.geometricTransport = trans.geometricTransport;
        conn.connectionTransport = trans.connectionTransport;
        
    otherwise
        error('bct:manifold:connection:UnknownType', ...
            'Unknown connection type: %s. Supported types: trivial', connType);
end

end
