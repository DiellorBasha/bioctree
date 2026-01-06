function gradF = gradient(DEC, f0)
%GRADIENT Compute gradient of 0-form (scalar field → vector field)
%
% ⚠️  DEPRECATED: Use bct.ops.dec.gradient instead
%
% Syntax:
%   gradF = bct.dec.gradient(DEC, f0)
%
% Inputs:
%   DEC - bct.DEC object
%   f0  - [N×1] 0-form (vertex-based scalar field)
%
% Returns:
%   gradF - [F×3] face-based tangent vectors
%
% Notes:
%   - Simple wrapper around DiscreteExteriorCalculus.gradient

warning('bct:dec:Deprecated', ...
    'bct.dec.gradient is deprecated. Use bct.ops.dec.gradient with DiscreteExteriorCalculus backend.');
%   - Gradient computed via exterior derivative d0
%   - Then converted to face vectors using sharp operator (primal1FormToDualVector)
%   - Returns tangent vectors at face centroids projected to tangent plane
%
% See also: bct.dec.divergence, bct.dec.curl, DiscreteExteriorCalculus

arguments
    DEC (1,1) bct.DEC
    f0 (:,1) double
end

% Delegate to DiscreteExteriorCalculus backend
Backend = DEC.backend();
gradF = Backend.gradient(f0);

end
