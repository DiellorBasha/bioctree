function tf = isSI(F)
%ISSI Check if field is in SI units
%
% Syntax:
%   tf = bct.field.metric.isSI(F)
%
% Inputs:
%   F - bct.Field object or field struct
%
% Outputs:
%   tf - true if field is in SI units (status="si")
%
% Description:
%   Convenience function to check if a field has been converted to SI.
%   Returns true if metric.status == "si".
%
% Examples:
%   tf = bct.field.metric.isSI(F);
%   if ~tf
%       F = bct.field.metric.toSI(F);
%   end
%
% See also: bct.field.metric.toSI, bct.field.metric.declare

% Get metric
if isa(F, 'bct.Field')
    metric = F.Metric;
else
    if ~isfield(F, 'metric')
        error('bct:field:metric:MissingMetric', ...
            'Field struct missing metric field');
    end
    metric = F.metric;
end

% Check status
tf = (metric.status == "si");

end
