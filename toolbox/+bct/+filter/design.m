function F = design(eigenvalues, kernelName, varargin)
%BCT.FILTER.DESIGN  Design a spectral filter or filterbank
%
%   F = bct.filter.design(eigenvalues, kernelName, paramName, paramValues)
%   F = bct.filter.design(eigenvalues, kernelName, "Params", params)
%
% Purpose
%   Creates a spectral filter or filterbank by evaluating a parameterized
%   kernel from bct.kernel on an eigenvalue axis. Supports both single
%   filters (J=1) and filterbanks (J>1) via parameter sweeps.
%
% Inputs
%   eigenvalues - [k×1] or [1×k] numeric vector, spectral axis
%   kernelName  - string or char, kernel name from bct.kernel.dictionary()
%
% Signature A: Filterbank via parameter sweep
%   F = bct.filter.design(eigenvalues, kernelName, paramName, paramValues, ...)
%   
%   paramName   - string, name of parameter to sweep
%   paramValues - scalar or vector, parameter values (J = numel(paramValues))
%
%   Name-Value Arguments:
%   Params      - struct (optional), additional fixed parameters
%                 Must NOT contain paramName (to avoid ambiguity)
%
% Signature B: Explicit parameter struct(s)
%   F = bct.filter.design(eigenvalues, kernelName, "Params", params, ...)
%   
%   Params      - struct or struct array
%                 If struct: J=1 (single filter)
%                 If struct array: J=numel(params) (filterbank)
%
% Common Name-Value Arguments
%   Strict          - logical (default true), enforce validation
%   SchemaVersion   - string (default "bct.filter@1"), internal use
%
% Output
%   F - Filter specification struct with fields:
%       .schema     - "bct.filter@1"
%       .type       - "spectral"
%       .kernelName - string, kernel identifier
%       .params     - [1×J] struct array, kernel parameters
%       .axis       - struct with:
%                       .type         - "eigenvalues"
%                       .eigenvalues  - [k×1] eigenvalue axis
%                       .k            - scalar, number of modes
%       .weights    - [k×J] evaluated spectral weights (J filters)
%       .meta       - struct, reserved (empty in v1)
%
% Algorithm
%   1. Parse signature (A or B) and build params struct array [1×J]
%   2. For each filter j=1:J:
%      - Bind parameters using bct.kernel.bind
%      - Evaluate kernel on eigenvalue axis
%      - Store as weights(:,j)
%   3. Return filter struct with [k×J] weights
%
% Validation (Strict=true)
%   - Kernel must exist in bct.kernel.dictionary()
%   - All weights must be finite (no NaN/Inf)
%   - Eigenvalues must be finite
%   - Output length must match k for each filter
%
% Examples
%   % Single filter
%   F = bct.filter.design(eigenvalues, "Heat", "tau", 10);
%   % F.weights is [k×1], F.params is [1×1] struct
%
%   % Filterbank via parameter sweep
%   taus = [1 10 25 50];
%   F = bct.filter.design(eigenvalues, "Heat", "tau", taus);
%   % F.weights is [k×4], F.params is [1×4] struct array
%
%   % Multi-parameter filterbank
%   params(1) = struct('mu', 0.1, 'sigma', 0.01);
%   params(2) = struct('mu', 0.2, 'sigma', 0.01);
%   F = bct.filter.design(eigenvalues, "Gaussian", "Params", params);
%
%   % Single filter with multiple fixed params
%   F = bct.filter.design(eigenvalues, "Gaussian", ...
%       "Params", struct('mu', 0, 'sigma', 0.5));
%
% See also: bct.filter.analysis, bct.filter.synthesis, bct.kernel.bind

%% Parse inputs
p = inputParser;
p.addRequired('eigenvalues', @(x) isnumeric(x) && isvector(x));
p.addRequired('kernelName', @(x) isstring(x) || ischar(x));
p.addOptional('paramNameOrParams', [], @(x) isstring(x) || ischar(x) || isstruct(x));
p.addOptional('paramValues', [], @isnumeric);
p.addParameter('Params', struct(), @isstruct);
p.addParameter('Strict', true, @islogical);
p.addParameter('SchemaVersion', "bct.filter@1", @isstring);

p.parse(eigenvalues, kernelName, varargin{:});
args = p.Results;

%% Basic input processing
kernelName = string(args.kernelName);
eigenvaluesColumn = args.eigenvalues(:);
k = numel(eigenvaluesColumn);

%% Determine signature and build params array
if ~isempty(args.paramNameOrParams)
    if isstruct(args.paramNameOrParams)
        % Signature B: explicit Params (struct or struct array)
        paramsArray = args.paramNameOrParams;
        J = numel(paramsArray);
        
        % Validate not mixing signatures
        if ~isempty(args.paramValues)
            error('bct:filter:design:AmbiguousSignature', ...
                'Cannot provide both struct Params and paramValues.');
        end
    else
        % Signature A: paramName/paramValues sweep
        paramName = string(args.paramNameOrParams);
        paramValues = args.paramValues;
        
        if isempty(paramValues)
            error('bct:filter:design:MissingParamValues', ...
                'Must provide paramValues when using paramName signature.');
        end
        
        J = numel(paramValues);
        baseParams = args.Params;
        
        % Check for parameter name conflict
        if isfield(baseParams, paramName)
            error('bct:filter:design:ConflictingParams', ...
                'Parameter "%s" appears in both paramName and Params struct.', ...
                paramName);
        end
        
        % Build struct array with parameter sweep
        paramsArray = repmat(baseParams, 1, J);
        for j = 1:J
            paramsArray(j).(paramName) = paramValues(j);
        end
    end
else
    % No positional params - must use Name-Value "Params"
    if isempty(fieldnames(args.Params))
        error('bct:filter:design:MissingParams', ...
            'Must provide either (paramName, paramValues) or "Params" struct.');
    end
    paramsArray = args.Params;
    J = numel(paramsArray);
end

%% Strict validation
if args.Strict
    % Validate eigenvalues are finite
    if any(~isfinite(eigenvaluesColumn))
        error('bct:filter:design:InvalidEigenvalues', ...
            'Eigenvalues must be finite (no NaN or Inf).');
    end
    
    % Check kernel exists in dictionary
    D = bct.kernel.dictionary();
    if ~isKey(D, kernelName)
        availableKernels = keys(D);
        error('bct:filter:design:UnknownKernel', ...
            ['Kernel "%s" not found in bct.kernel.dictionary().\n' ...
             'Available kernels: %s'], ...
            kernelName, strjoin(availableKernels, ', '));
    end
end

%% Evaluate kernel for each filter in bank
weightsMatrix = zeros(k, J);

for j = 1:J
    try
        % Bind parameters to kernel
        kernelFcn = bct.kernel.bind(kernelName, paramsArray(j));
        
        % Evaluate on eigenvalue axis
        weights = kernelFcn(eigenvaluesColumn);
        weightsMatrix(:, j) = weights(:);
        
    catch ME
        error('bct:filter:design:KernelEvaluationFailed', ...
            'Failed to bind/evaluate kernel "%s" for filter %d: %s', ...
            kernelName, j, ME.message);
    end
end

%% Post-evaluation validation (Strict mode)
if args.Strict
    % Check all weights are finite
    if any(~isfinite(weightsMatrix(:)))
        error('bct:filter:design:NonFiniteWeights', ...
            'Kernel "%s" produced non-finite weights (NaN or Inf).', ...
            kernelName);
    end
end

%% Construct filter specification struct
% Ensure paramsArray is row vector [1×J]
if size(paramsArray, 1) > 1
    paramsArray = reshape(paramsArray, 1, []);
end

F = struct( ...
    'schema',     args.SchemaVersion, ...
    'type',       "spectral", ...
    'kernelName', kernelName, ...
    'params',     paramsArray, ...     % [1×J] struct array
    'axis',       struct( ...
                    'type',        "eigenvalues", ...
                    'eigenvalues', eigenvaluesColumn, ...
                    'k',           k), ...
    'weights',    weightsMatrix, ...   % [k×J]
    'meta',       struct() );

end
