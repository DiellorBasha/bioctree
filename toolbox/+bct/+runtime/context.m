function ctx = context(Manifold, options)
%CONTEXT Create runtime context from Manifold
%
% Syntax:
%   ctx = bct.runtime.context(Manifold)
%   ctx = bct.runtime.context(Manifold, 'FEM', true, 'DEC', false)
%
% Inputs:
%   Manifold - bct.Manifold object
%
% Optional Parameters:
%   DEC   - Create DEC representation (default: false)
%   Graph - Create Graph representation (default: false)
%
% Returns:
%   ctx - Context struct with available representations
%
% The context is the bridge between static registry and live execution.
% It contains the Manifold and requested representations.
%
% Example:
%   M = bct.Manifold(struct('V', V, 'F', F));
%   ctx = bct.runtime.context(M, 'DEC', true);
%   ops = bct.runtime.operators(ctx);
%
% See also: bct.runtime.operators

arguments
    Manifold (1,1) bct.Manifold
    options.DEC   (1,1) logical = false
    options.Graph (1,1) logical = false
end

% Initialize context with Manifold
ctx = struct('Manifold', Manifold);

% Add requested representations (lazy creation via Manifold ports)
if options.DEC
    try
        ctx.DEC = Manifold.DEC();
    catch ME
        warning('bct:runtime:DECUnavailable', ...
            'DEC representation failed to initialize: %s', ME.message);
    end
end

if options.Graph
    try
        ctx.Graph = Manifold.Graph();
    catch ME
        warning('bct:runtime:GraphUnavailable', ...
            'Graph representation failed to initialize: %s', ME.message);
    end
end

end
