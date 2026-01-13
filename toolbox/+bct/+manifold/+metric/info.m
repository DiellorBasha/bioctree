function info = info(M)
%INFO Return metric provenance information for manifold
%
% Syntax:
%   info = bct.manifold.metric.info(M)
%
% Inputs:
%   M - bct.Manifold object
%
% Outputs:
%   info - Structure with metric provenance fields:
%          .unit              - Always "m" (meters)
%          .rescaleApplied    - Logical, true if rescale was applied
%          .rescaleFromUnit   - Source unit string (empty if not rescaled)
%          .rescaleFactor     - Conversion factor used (1.0 if not rescaled)
%          .rescaleTimestamp  - When rescaling was applied (empty if not)
%
% Description:
%   Returns a small report about the manifold's metric provenance.
%   Useful for debugging and health reporting. Does not imply
%   configurability - all manifolds are always in meters.
%
% Examples:
%   M = bct.Manifold(V, F);
%   info = bct.manifold.metric.info(M);
%   % info.unit = "m"
%   % info.rescaleApplied = false
%
%   M = bct.manifold.metric.rescale(M, 'From', 'mm');
%   info = bct.manifold.metric.info(M);
%   % info.rescaleApplied = true
%   % info.rescaleFromUnit = "mm"
%   % info.rescaleFactor = 1e-3
%
% See also: bct.manifold.metric.rescale, bct.Manifold

arguments
    M (1,1) bct.Manifold
end

info = struct();
info.unit = M.Metric.unit;
info.rescaleApplied = M.Metric.rescale.applied;
info.rescaleFromUnit = M.Metric.rescale.fromUnit;
info.rescaleFactor = M.Metric.rescale.factor;
info.rescaleTimestamp = M.Metric.rescale.timestamp;

end
