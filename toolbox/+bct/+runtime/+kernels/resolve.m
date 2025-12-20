function spec = resolve(id, axis, options)
%BCT.RUNTIME.KERNELS.RESOLVE  Resolve kernel ID to executable KernelSpec
%
%   spec = bct.runtime.kernels.resolve(id, axis)
%   spec = bct.runtime.kernels.resolve(id, axis, Name, Value, ...)
%
% Purpose
%   Resolves a kernel ID into a complete, executable KernelSpec with:
%   - Computed defaults and ranges for given axis
%   - Merged parameter overrides
%   - Validated parameters (optional)
%   - Ready-to-use evaluator and factory functions
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
%   spec - KernelSpec struct with fields:
%          Id            (string): kernel identifier
%          Kind          (string): kernel kind
%          Axis          (numeric): provided axis vector
%          ParamNames    (string array): parameter names
%          Defaults      (struct): default parameters for this axis
%          Ranges        (struct): valid parameter ranges for this axis
%          Params        (struct): final parameters (defaults + overrides)
%          Evaluate      (function_handle): @(x,p)->y
%          Factory       (function_handle): @(p)->@(x)->y (convenience)
%          AxisKinds     (string array): allowed axis kinds
%          [Name, Tags, EquationLatex, Notes, IsComplex if present in registry]
%
% Usage
%   % Basic usage with defaults
%   axis = linspace(-5, 5, 501).';
%   spec = bct.runtime.kernels.resolve("Gaussian", axis);
%   y = spec.Evaluate(axis, spec.Params);
%
%   % Override parameters
%   spec = bct.runtime.kernels.resolve("Gaussian", axis, ...
%       "Params", struct('mu', 0, 'sigma', 0.5));
%   y = spec.Evaluate(axis, spec.Params);
%
%   % Use factory pattern
%   kernel = spec.Factory(spec.Params);
%   y = kernel(axis);
%
% See also: bct.runtime.kernels.dictionary, bct.kernel.get

    arguments
        id (1,1) string
        axis (:,1) {mustBeNumeric}
        options.Params (1,1) struct = struct()
        options.ValidateParams (1,1) logical = true
        options.AllowOutOfRange (1,1) logical = false
    end
    
    % Get registry entry
    defs = bct.registry.kernels.defs();
    idx = find([defs.Id] == id, 1);
    
    if isempty(idx)
        error('bct:runtime:kernels:UnknownId', ...
            'Unknown kernel ID: "%s". Available: %s', ...
            id, strjoin(string({defs.Id}), ', '));
    end
    
    entry = defs(idx);
    
    % Compute defaults and ranges for this axis
    try
        defaults = entry.DefaultParams(axis);
    catch ME
        error('bct:runtime:kernels:DefaultParamsFailed', ...
            'Failed to compute default parameters for kernel "%s": %s', ...
            id, ME.message);
    end
    
    try
        ranges = entry.ParamRanges(axis);
    catch ME
        error('bct:runtime:kernels:ParamRangesFailed', ...
            'Failed to compute parameter ranges for kernel "%s": %s', ...
            id, ME.message);
    end
    
    % Merge parameters (defaults + overrides)
    params = defaults;
    if ~isempty(fieldnames(options.Params))
        overrideFields = string(fieldnames(options.Params));
        for i = 1:numel(overrideFields)
            params.(overrideFields(i)) = options.Params.(overrideFields(i));
        end
    end
    
    % Validate parameters if requested
    if options.ValidateParams
        paramFields = string(fieldnames(params));
        
        % Check all required parameters present
        missingParams = setdiff(entry.ParamNames, paramFields);
        if ~isempty(missingParams)
            error('bct:runtime:kernels:MissingParameters', ...
                'Kernel "%s" missing required parameters: %s', ...
                id, strjoin(missingParams, ', '));
        end
        
        % Check no extra parameters
        extraParams = setdiff(paramFields, entry.ParamNames);
        if ~isempty(extraParams)
            warning('bct:runtime:kernels:ExtraParameters', ...
                'Kernel "%s" has extra parameters that will be ignored: %s', ...
                id, strjoin(extraParams, ', '));
        end
        
        % Check parameter ranges (if not allowing out-of-range)
        if ~options.AllowOutOfRange
            for i = 1:numel(entry.ParamNames)
                pname = entry.ParamNames(i);
                if isfield(params, pname) && isfield(ranges, pname)
                    pval = params.(pname);
                    prange = ranges.(pname);
                    if isscalar(pval) && numel(prange) == 2
                        if pval < prange(1) || pval > prange(2)
                            error('bct:runtime:kernels:ParameterOutOfRange', ...
                                'Parameter "%s" = %g is outside valid range [%g, %g] for kernel "%s"', ...
                                pname, pval, prange(1), prange(2), id);
                        end
                    end
                end
            end
        end
    end
    
    % Build KernelSpec output
    spec = struct();
    spec.Id = entry.Id;
    spec.Kind = entry.Kind;
    spec.Axis = axis;
    spec.ParamNames = entry.ParamNames;
    spec.Defaults = defaults;
    spec.Ranges = ranges;
    spec.Params = params;
    spec.Evaluate = entry.Evaluate;
    spec.Factory = @(p) @(x) entry.Evaluate(x, p);  % Derived convenience
    spec.AxisKinds = entry.AxisKinds;
    
    % Copy optional fields if present
    if isfield(entry, 'Name'), spec.Name = entry.Name; end
    if isfield(entry, 'Tags'), spec.Tags = entry.Tags; end
    if isfield(entry, 'EquationLatex'), spec.EquationLatex = entry.EquationLatex; end
    if isfield(entry, 'Notes'), spec.Notes = entry.Notes; end
    if isfield(entry, 'IsComplex'), spec.IsComplex = entry.IsComplex; end
end
