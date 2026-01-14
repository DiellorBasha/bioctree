function F = declare(F, options)
%DECLARE Declare the physical unit meaning of a field
%
% Syntax:
%   F = bct.field.metric.declare(F, 'Quantity', quantity, 'Unit', unit)
%   F = bct.field.metric.declare(F, Name=Value)
%
% Inputs:
%   F - bct.Field object or field struct
%
% Name-Value Arguments (required):
%   Quantity - String specifying physical quantity
%   Unit     - String specifying current unit of values
%
% Name-Value Arguments (optional):
%   SIUnit     - Override SI unit (default: from spec if available)
%   Dim        - Override dimension struct (default: from spec)
%   ScaleToSI  - Override scale factor (default: from spec)
%   OffsetToSI - Override offset (default: from spec)
%   Strict     - Enforce spec existence (default: true)
%
% Outputs:
%   F - Field with updated Metric (values unchanged)
%
% Description:
%   Declares the physical unit meaning of a field without modifying
%   its values. Sets metric.status to "declared".
%
%   If spec(quantity, unit) exists, metric is initialized from it.
%   User can override with explicit parameters.
%
%   This function does NOT modify F.Value - use toSI() to convert values.
%
% Examples:
%   % Declare temperature field in Celsius
%   F = bct.field.metric.declare(F, 'Quantity', 'temperature', 'Unit', 'degC');
%
%   % Declare with manual parameters
%   F = bct.field.metric.declare(F, ...
%       'Quantity', 'custom', 'Unit', 'arb', ...
%       'SIUnit', '1', 'Strict', false);
%
% See also: bct.field.metric.toSI, bct.field.metric.spec, bct.field.metric.validate

arguments
    F  % bct.Field or struct
    options.Quantity (1,1) string
    options.Unit (1,1) string
    options.SIUnit (1,1) string = ""
    options.Dim struct = struct()
    options.ScaleToSI (1,1) double = nan
    options.OffsetToSI (1,1) double = nan
    options.Strict (1,1) logical = true
end

% Determine if input is OO wrapper or struct
isOO = isa(F, 'bct.Field');

% Initialize metric from spec if available
try
    specData = bct.field.metric.spec(options.Quantity, options.Unit);
    metric = struct();
    metric.quantity = options.Quantity;
    metric.unit = options.Unit;
    metric.siUnit = specData.siUnit;
    metric.dim = specData.dim;
    metric.scaleToSI = specData.scaleToSI;
    metric.offsetToSI = specData.offsetToSI;
    metric.status = "declared";
    metric.version = 1;
catch ME
    if options.Strict
        rethrow(ME);
    else
        % Build minimal metric with user overrides
        metric = bct.field.metric.default();
        metric.quantity = options.Quantity;
        metric.unit = options.Unit;
        metric.status = "declared";
    end
end

% Apply user overrides
if options.SIUnit ~= ""
    metric.siUnit = options.SIUnit;
end
if ~isempty(fieldnames(options.Dim))
    % Merge with existing dims
    dimFields = fieldnames(options.Dim);
    for i = 1:length(dimFields)
        metric.dim.(dimFields{i}) = options.Dim.(dimFields{i});
    end
end
if ~isnan(options.ScaleToSI)
    metric.scaleToSI = options.ScaleToSI;
end
if ~isnan(options.OffsetToSI)
    metric.offsetToSI = options.OffsetToSI;
end

% Validate final metric
bct.field.metric.validate(metric);

% Attach to field
if isOO
    % Update OO wrapper (need to modify private property)
    % Convert to struct, modify, convert back
    s = F.toStruct();
    s.metric = metric;
    F = bct.Field.fromStruct(s);
else
    % Update struct directly
    F.metric = metric;
end

end
