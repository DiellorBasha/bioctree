function F = toSI(F, options)
%TOSI Convert field values to SI units and update metric
%
% Syntax:
%   F = bct.field.metric.toSI(F)
%   F = bct.field.metric.toSI(F, 'Strict', false)
%
% Inputs:
%   F - bct.Field object or field struct
%
% Name-Value Arguments:
%   Strict - Require declared status (default: true)
%
% Outputs:
%   F - Field with values converted to SI and metric updated
%
% Description:
%   Converts stored field values to SI units using the conversion
%   parameters in the metric:
%
%     ValueSI = scaleToSI * Value + offsetToSI
%
%   Updates metric:
%   - unit → siUnit
%   - status → "si"
%   - scaleToSI → 1.0
%   - offsetToSI → 0.0
%
%   In strict mode (default), requires metric.status to be "declared"
%   or "si" (not "unset").
%
% Examples:
%   % Convert temperature from Celsius to Kelvin
%   F = bct.field.metric.declare(F, 'Quantity', 'temperature', 'Unit', 'degC');
%   F = bct.field.metric.toSI(F);
%   % F.Value now in Kelvin, F.Metric.unit = "K", F.Metric.status = "si"
%
%   % Non-strict mode (allows unset)
%   F = bct.field.metric.toSI(F, 'Strict', false);
%
% See also: bct.field.metric.declare, bct.field.metric.isSI

arguments
    F  % bct.Field or struct
    options.Strict (1,1) logical = true
end

% Determine if input is OO wrapper or struct
isOO = isa(F, 'bct.Field');

% Get metric
if isOO
    metric = F.Metric;
    value = F.Value;
else
    if ~isfield(F, 'metric')
        error('bct:field:metric:MissingMetric', ...
            'Field struct missing metric field');
    end
    metric = F.metric;
    value = F.value;
end

% Validate current status
if options.Strict && metric.status == "unset"
    error('bct:field:metric:UnsetStatus', ...
        'Cannot convert to SI: metric status is "unset". Use declare() first.');
end

% Early return if already in SI
if metric.status == "si"
    return;
end

% Apply conversion: ValueSI = scale * Value + offset
valueSI = metric.scaleToSI * value + metric.offsetToSI;

% Update metric
metric.unit = metric.siUnit;
metric.status = "si";
metric.scaleToSI = 1.0;
metric.offsetToSI = 0.0;

% Validate updated metric
bct.field.metric.validate(metric);

% Update field
if isOO
    % Convert to struct, modify, convert back
    s = F.toStruct();
    s.value = valueSI;
    s.metric = metric;
    F = bct.Field.fromStruct(s);
else
    % Update struct directly
    F.value = valueSI;
    F.metric = metric;
end

end
