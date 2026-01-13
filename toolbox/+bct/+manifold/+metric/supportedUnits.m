function units = supportedUnits()
%SUPPORTEDUNITS Return list of supported length units
%
% Syntax:
%   units = bct.manifold.metric.supportedUnits()
%
% Outputs:
%   units - String array of supported length units
%
% Description:
%   Returns the list of decimal length units supported by the metric
%   subsystem. All units are decimal multiples of meters.
%
% Supported Units:
%   - "m"  : meters (SI base)
%   - "cm" : centimeters (10^-2 m)
%   - "mm" : millimeters (10^-3 m)
%   - "um" : micrometers (10^-6 m)
%   - "nm" : nanometers (10^-9 m)
%
% Examples:
%   units = bct.manifold.metric.supportedUnits();
%   % Returns: ["m", "cm", "mm", "um", "nm"]
%
% See also: bct.manifold.metric.validateUnit, bct.manifold.metric.rescale

units = ["m", "cm", "mm", "um", "nm"];

end
