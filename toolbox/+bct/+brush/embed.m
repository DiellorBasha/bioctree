function w = embed(indices, N, weights)
%BCT.BRUSH.EMBED  Embed a sparse selection on an axis
%
%   w = bct.brush.embed(indices, N)
%   w = bct.brush.embed(indices, N, weights)
%
%   indices : vector of indices
%   N       : axis length
%   weights : optional weights (same length as indices)
%
%   Output
%   ------
%   w       : N×1 sparse double

    arguments
        indices (:,1) double {mustBeInteger, mustBePositive}
        N (1,1) double {mustBeInteger, mustBePositive}
        weights (:,1) double = []
    end

    if isempty(weights)
        weights = ones(numel(indices),1);
    end

    if numel(weights) ~= numel(indices)
        error('bct:brush:embed', ...
              'weights must match indices length');
    end

    w = sparse(indices, ones(size(indices)), weights, N, 1);
end
