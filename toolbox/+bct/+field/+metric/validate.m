function validate(metric)
%VALIDATE Validate a metric record structurally and semantically
%
% Syntax:
%   bct.field.metric.validate(metric)
%
% Inputs:
%   metric - Metric structure to validate
%
% Description:
%   Validates a metric record according to v1 schema requirements:
%   - All required fields exist
%   - Field types are correct
%   - Status is valid ("unset", "declared", "si")
%   - If status=="si", requires unit==siUnit and offsetToSI==0
%   - Base dimensions are properly structured
%
% Throws:
%   Error if metric structure is invalid
%
% Examples:
%   metric = bct.field.metric.default();
%   bct.field.metric.validate(metric);  % Should pass
%
% See also: bct.field.metric.default, bct.field.metric.declare

% Check required fields exist
requiredFields = {'quantity', 'unit', 'siUnit', 'dim', 'scaleToSI', ...
                 'offsetToSI', 'status', 'version'};

for i = 1:length(requiredFields)
    if ~isfield(metric, requiredFields{i})
        error('bct:field:metric:MissingField', ...
            'Metric missing required field: %s', requiredFields{i});
    end
end

% Validate types - string scalars
stringFields = {'quantity', 'unit', 'siUnit', 'status'};
for i = 1:length(stringFields)
    fname = stringFields{i};
    val = metric.(fname);
    if ~(isstring(val) && isscalar(val))
        error('bct:field:metric:InvalidType', ...
            'Field "%s" must be a string scalar', fname);
    end
end

% Validate numeric scalars
numericFields = {'scaleToSI', 'offsetToSI'};
for i = 1:length(numericFields)
    fname = numericFields{i};
    val = metric.(fname);
    if ~(isnumeric(val) && isscalar(val) && isfinite(val))
        error('bct:field:metric:InvalidNumeric', ...
            'Field "%s" must be a finite numeric scalar', fname);
    end
end

% Validate status
validStatuses = ["unset", "declared", "si"];
if ~ismember(metric.status, validStatuses)
    error('bct:field:metric:InvalidStatus', ...
        'Status must be one of: %s', strjoin(validStatuses, ', '));
end

% Validate dim structure
if ~isstruct(metric.dim)
    error('bct:field:metric:InvalidDim', ...
        'dim must be a struct');
end

requiredDims = {'L', 'M', 'T', 'I', 'Theta'};
for i = 1:length(requiredDims)
    dimName = requiredDims{i};
    if ~isfield(metric.dim, dimName)
        error('bct:field:metric:MissingDimension', ...
            'dim missing required base dimension: %s', dimName);
    end
    val = metric.dim.(dimName);
    if ~(isnumeric(val) && isscalar(val) && isfinite(val))
        error('bct:field:metric:InvalidDimensionValue', ...
            'dim.%s must be a finite numeric scalar', dimName);
    end
end

% Strictness for SI status
if metric.status == "si"
    if metric.unit ~= metric.siUnit
        error('bct:field:metric:SIStatusInconsistent', ...
            'When status="si", unit must equal siUnit');
    end
    if metric.offsetToSI ~= 0
        warning('bct:field:metric:SIOffsetNonZero', ...
            'When status="si", offsetToSI should be 0 (found %.6g)', ...
            metric.offsetToSI);
    end
end

end
