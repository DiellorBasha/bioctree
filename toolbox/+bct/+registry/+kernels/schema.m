function S = schema()
%BCT.REGISTRY.KERNELS.SCHEMA  Schema definition for kernel registry entries
%
%   S = bct.registry.kernels.schema()
%
% Purpose
%   Returns declarative specification of required/optional fields and
%   invariant checks for kernel registry entries. Used by validate().
%
% Output
%   S - struct with fields:
%       RequiredFields   (string array): must be present in every entry
%       OptionalFields   (string array): may be present
%       ValidateEntry    (function_handle): @(entry)->mustPassOrError
%
% Contract
%   Schema enables centralized validation and future tooling extensions.
%   All validation logic should ultimately refer to this schema.
%
% See also: bct.registry.kernels.validate, bct.registry.kernels.defs

    S = struct();
    
    % Required fields (must be present in every entry)
    S.RequiredFields = [ ...
        "Id", ...
        "Kind", ...
        "AxisKinds", ...
        "ParamNames", ...
        "DefaultParams", ...
        "ParamRanges", ...
        "Evaluate" ...
    ];
    
    % Optional fields (may be present)
    S.OptionalFields = [ ...
        "Name", ...
        "Tags", ...
        "EquationLatex", ...
        "Notes", ...
        "IsComplex" ...
    ];
    
    % Allowed values for Kind
    S.AllowedKinds = [ ...
        "smoothing", ...
        "wavelet", ...
        "window", ...
        "impulse", ...
        "distance" ...
    ];
    
    % Allowed values for AxisKinds elements
    S.AllowedAxisKinds = [ ...
        "lambda", ...
        "time", ...
        "frequency", ...
        "distance", ...
        "index", ...
        "generic" ...
    ];
    
    % Entry-level validator
    S.ValidateEntry = @validateEntry;
end

function validateEntry(entry)
    % Validates a single kernel registry entry
    % Throws error if validation fails
    
    % Check Id
    mustBeTextScalar(entry.Id);
    assert(strlength(entry.Id) > 0, 'bct:registry:kernels:EmptyId', ...
        'Kernel Id must be non-empty');
    
    % Check Kind
    S = bct.registry.kernels.schema();
    mustBeTextScalar(entry.Kind);
    mustBeMember(entry.Kind, S.AllowedKinds);
    
    % Check AxisKinds
    mustBeText(entry.AxisKinds);
    assert(numel(entry.AxisKinds) > 0, 'bct:registry:kernels:EmptyAxisKinds', ...
        'AxisKinds must be non-empty string array');
    for i = 1:numel(entry.AxisKinds)
        mustBeMember(entry.AxisKinds(i), S.AllowedAxisKinds);
    end
    
    % Check ParamNames
    mustBeText(entry.ParamNames);
    assert(numel(unique(entry.ParamNames)) == numel(entry.ParamNames), ...
        'bct:registry:kernels:DuplicateParamNames', ...
        'ParamNames must be unique for kernel %s', entry.Id);
    
    % Check DefaultParams is function handle
    assert(isa(entry.DefaultParams, 'function_handle'), ...
        'bct:registry:kernels:InvalidDefaultParams', ...
        'DefaultParams must be function_handle for kernel %s', entry.Id);
    
    % Check ParamRanges is function handle
    assert(isa(entry.ParamRanges, 'function_handle'), ...
        'bct:registry:kernels:InvalidParamRanges', ...
        'ParamRanges must be function_handle for kernel %s', entry.Id);
    
    % Check Evaluate is function handle with arity 2
    assert(isa(entry.Evaluate, 'function_handle'), ...
        'bct:registry:kernels:InvalidEvaluate', ...
        'Evaluate must be function_handle for kernel %s', entry.Id);
    
    % Validate execution on sample axis
    axisSample = linspace(-1, 1, 9).';
    
    % Test DefaultParams(axis)
    try
        p0 = entry.DefaultParams(axisSample);
        assert(isstruct(p0), 'DefaultParams must return struct');
        p0Fields = string(fieldnames(p0));
        assert(numel(p0Fields) == numel(entry.ParamNames) && all(ismember(entry.ParamNames, p0Fields)), ...
            'DefaultParams must return struct with all ParamNames fields');
    catch ME
        error('bct:registry:kernels:DefaultParamsExecution', ...
            'DefaultParams failed for kernel %s: %s', entry.Id, ME.message);
    end
    
    % Test ParamRanges(axis)
    try
        pr = entry.ParamRanges(axisSample);
        assert(isstruct(pr), 'ParamRanges must return struct');
        prFields = string(fieldnames(pr));
        assert(numel(prFields) == numel(entry.ParamNames) && all(ismember(entry.ParamNames, prFields)), ...
            'ParamRanges must return struct with all ParamNames fields');
    catch ME
        error('bct:registry:kernels:ParamRangesExecution', ...
            'ParamRanges failed for kernel %s: %s', entry.Id, ME.message);
    end
    
    % Test Evaluate(x, p)
    try
        y = entry.Evaluate(axisSample, p0);
        assert(isnumeric(y) && isequal(size(y), size(axisSample)), ...
            'Evaluate must return numeric array matching axis shape');
    catch ME
        error('bct:registry:kernels:EvaluateExecution', ...
            'Evaluate failed for kernel %s: %s', entry.Id, ME.message);
    end
    
    % Validate optional fields if present
    if isfield(entry, 'Name')
        mustBeTextScalar(entry.Name);
    end
    
    if isfield(entry, 'Tags')
        mustBeText(entry.Tags);
    end
    
    if isfield(entry, 'EquationLatex')
        mustBeTextScalar(entry.EquationLatex);
    end
    
    if isfield(entry, 'Notes')
        mustBeTextScalar(entry.Notes);
    end
    
    if isfield(entry, 'IsComplex')
        mustBeNumericOrLogical(entry.IsComplex);
        assert(isscalar(entry.IsComplex), 'IsComplex must be scalar');
    end
end
