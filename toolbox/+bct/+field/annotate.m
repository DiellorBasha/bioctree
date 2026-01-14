function F = annotate(F, options)
%ANNOTATE Add metric annotation to field struct
%
% Syntax:
%   F = bct.field.annotate(F)
%   F = bct.field.annotate(F, 'Quantity', quantityName)
%   F = bct.field.annotate(F, 'Metric', metricStruct)
%
% Inputs:
%   F - Field struct (from bct.field.make or field generators)
%
% Name-Value Arguments:
%   Quantity - Predefined quantity name: "unknown" | "temperature" | "velocity" | "force" | ...
%   Metric   - Explicit metric struct (overrides Quantity)
%   Strict   - Enforce validation (default: true)
%
% Outputs:
%   F - Field struct with .metric field added
%
% Description:
%   Adds or updates the metric field in a Field struct. The metric contains
%   physical unit and dimension information following the schema defined in
%   bct.field.metric.
%
%   If no arguments are provided, adds a default "unset" metric.
%   If a Quantity name is provided, uses the corresponding predefined metric.
%   If an explicit Metric struct is provided, validates and uses it directly.
%
% Examples:
%   % Add default metric
%   F = bct.field.generate.delta(10, M);
%   F = bct.field.annotate(F);
%
%   % Annotate as temperature
%   F = bct.field.annotate(F, 'Quantity', 'temperature');
%
%   % Custom metric
%   metric = bct.field.metric.declare('velocity', 'm/s', 'm/s', [1 0 -1 0 0]);
%   F = bct.field.annotate(F, 'Metric', metric);
%
% See also: bct.field.metric.default, bct.field.metric.declare, bct.field.validate

arguments
    F struct
    options.Quantity (1,1) string = "unknown"
    options.Metric struct = struct([])
    options.Strict (1,1) logical = true
end

% If explicit metric provided, use it
if ~isempty(fieldnames(options.Metric))
    F.metric = options.Metric;
    
    % Validate if strict
    if options.Strict
        bct.field.metric.validate(F.metric);
    end
    return;
end

% Otherwise, get or create metric based on quantity
if options.Quantity == "unknown"
    % Use default unset metric
    F.metric = bct.field.metric.default();
else
    % Try to get predefined quantity metric
    % For now, just use default with the quantity name
    F.metric = bct.field.metric.default();
    F.metric.quantity = options.Quantity;
end

% Validate if strict
if options.Strict
    bct.field.metric.validate(F.metric);
end

end
