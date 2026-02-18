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
%   % Default type is trivial
%   conn = bct.manifold.connection(M, ...
%       'singularities', [100, 500]);
%   
%   % Combined transport (geometric + connection)
%   trans = bct.manifold.connection.transport(M, conn);
%   combined = trans.combinedTransport.value;
%
% See also: bct.manifold.connection.trivial, bct.manifold.connection.transport

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.connection';
p.KeepUnmatched = true;
addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
addOptional(p, 'type', 'trivial', @(x) ischar(x) || isstring(x));
parse(p, M, varargin{:});

connType = string(p.Results.type);
remainingArgs = struct2cell(p.Unmatched);
remainingNames = fieldnames(p.Unmatched);
nameValuePairs = [remainingNames'; remainingArgs'];
nameValuePairs = nameValuePairs(:)';

% Dispatch to appropriate connection function
switch lower(connType)
    case 'trivial'
        conn = bct.manifold.connection.trivial(M, nameValuePairs{:});
        
    otherwise
        error('bct:manifold:connection:UnknownType', ...
            'Unknown connection type: %s. Supported types: trivial', connType);
end

end
