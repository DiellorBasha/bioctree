function spec = get(id, axis, options)
%BCT.KERNEL.GET  Get resolved kernel specification (façade)
%
%   spec = bct.kernel.get(id, axis)
%   spec = bct.kernel.get(id, axis, Name, Value, ...)
%
% Purpose
%   User-facing wrapper that delegates to bct.runtime.kernels.resolve().
%   Returns a complete, executable KernelSpec with computed defaults.
%
% Inputs
%   id   - string scalar, kernel identifier
%   axis - numeric vector, axis values for computing defaults/ranges
%
% Name-Value Arguments
%   Params            - struct, override default parameters
%   ValidateParams    - logical (default true), validate param values
%   AllowOutOfRange   - logical (default false), allow out-of-range params
%
% Output
%   spec - KernelSpec struct (see bct.runtime.kernels.resolve for fields)
%
% Usage
%   % Basic usage with defaults
%   axis = linspace(-5, 5, 501).';
%   spec = bct.kernel.get("Gaussian", axis);
%   y = spec.Evaluate(axis, spec.Params);
%
%   % Override parameters
%   spec = bct.kernel.get("Gaussian", axis, ...
%       "Params", struct('mu', 0, 'sigma', 0.5));
%
%   % Use factory pattern
%   kernel = spec.Factory(spec.Params);
%   y = kernel(axis);
%
% Note
%   This is a façade function. For new code, prefer:
%     spec = bct.runtime.kernels.resolve(id, axis, ...);
%
% See also: bct.runtime.kernels.resolve, bct.kernel.list, bct.kernel.dictionary

    arguments
        id (1,1) string
        axis (:,1) {mustBeNumeric}
        options.Params (1,1) struct = struct()
        options.ValidateParams (1,1) logical = true
        options.AllowOutOfRange (1,1) logical = false
    end
    
    % Delegate to authoritative runtime
    spec = bct.runtime.kernels.resolve(id, axis, ...
        "Params", options.Params, ...
        "ValidateParams", options.ValidateParams, ...
        "AllowOutOfRange", options.AllowOutOfRange);
end
