function dual = dualWeights(weights, epsilon, strict)
%DUALWEIGHTS  Compute canonical dual weights for filterbank reconstruction
%
%   dual = dualWeights(weights, epsilon, strict)
%
% Purpose
%   Computes the canonical dual weights for a filterbank given the analysis
%   weights. The dual weights enable stable reconstruction from subbands.
%
% Inputs
%   weights - [k×J] spectral weights matrix (J filters)
%   epsilon - scalar, regularization threshold for frame power
%             If >0, applies S = max(S, epsilon) to avoid division by zero
%             If 0, enforces strict validation (error if S==0)
%   strict  - logical, enforce strict validation
%
% Output
%   dual - [k×J] dual weights matrix
%
% Algorithm
%   For each eigenmode i=1:k, compute frame power:
%     S(i) = sum_j |weights(i,j)|^2
%   
%   Then dual weights are:
%     dual(i,j) = conj(weights(i,j)) / S(i)
%   
%   For real-valued kernels (typical case): dual = weights ./ S
%
% Validation (strict=true, epsilon=0)
%   - Error if any S(i) is zero or below tolerance
%   - This indicates the filterbank does not cover eigenmode i
%
% See also: bct.filter.inverse

arguments
    weights (:,:) {mustBeNumeric}
    epsilon (1,1) {mustBeNumeric, mustBeNonnegative} = 0
    strict (1,1) logical = true
end

% Compute per-mode frame power
% S(i) = sum over j of |weights(i,j)|^2
S = sum(abs(weights).^2, 2);  % [k×1]

% Handle zero or near-zero frame power
if epsilon > 0
    % Regularization: clamp S to minimum epsilon
    S = max(S, epsilon);
elseif strict
    % Strict mode: error if any S is zero or below tolerance
    tol = 1e-14;  % Numerical tolerance for "effectively zero"
    zeroModes = find(S < tol);
    
    if ~isempty(zeroModes)
        error('bct:filter:dualWeights:ZeroFramePower', ...
            ['Filterbank has zero frame power at %d eigenmode(s): [%s]\n' ...
             'These modes are not covered by the filterbank.\n' ...
             'Options:\n' ...
             '  1. Redesign filterbank to cover all modes\n' ...
             '  2. Use "Epsilon" parameter to regularize\n' ...
             '  3. Reduce number of eigenmodes k'], ...
            numel(zeroModes), ...
            num2str(zeroModes(:)', '%d '));
    end
end

% Compute dual weights: conj(weights) ./ S
% For real-valued weights (typical), conj() is identity
dual = conj(weights) ./ S;  % [k×J] with broadcasting across columns

end
