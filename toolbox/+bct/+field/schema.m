function s = schema()
%SCHEMA Return Field schema definition
%
% Syntax:
%   s = bct.field.schema()
%
% Returns:
%   s - Struct describing Field schema v1
%
% Schema includes:
%   - Supported support types
%   - Supported value types
%   - Value shape rules
%   - Time structure schema
%   - Required/optional fields
%
% See also: bct.field.validate, bct.field.make

s = struct();

% Schema version
s.version = "bct.field@1";

% Supported support types
s.supports = ["vertex", "face", "edge", "halfedge", "dualFace", "dualVertex"];

% Supported value types
s.valueTypes = ["scalar", "vector3", "tangent2", "complexScalar", "complexVector3"];

% Required fields for a valid Field
s.requiredFields = ["schemaVersion", "meshId", "support", "value", ...
                    "valueType", "time", "meta", "metric"];

% Optional fields
s.optionalFields = ["frame", "units", "provenance"];

% Value shape rules (dimensions beyond support cardinality)
s.valueShapes = struct();
s.valueShapes.scalar = struct('static', [1], 'timeSeries', [NaN]);  % [S×1] or [S×T]
s.valueShapes.vector3 = struct('static', [3], 'timeSeries', [3, NaN]);  % [S×3] or [S×3×T]
s.valueShapes.tangent2 = struct('static', [2], 'timeSeries', [2, NaN]);  % [S×2] or [S×2×T]
s.valueShapes.complexScalar = struct('static', [1], 'timeSeries', [NaN]);
s.valueShapes.complexVector3 = struct('static', [3], 'timeSeries', [3, NaN]);

% Frame requirements
s.frameRequired = ["tangent2"];

% Time struct schema
s.timeSchema = struct();
s.timeSchema.requiredIfPresent = ["nSamples"];
s.timeSchema.optional = ["fs", "t0", "t", "units"];
s.timeSchema.defaults = struct('t0', 0, 'units', "s");

% Frame struct schema
s.frameSchema = struct();
s.frameSchema.required = ["domain", "e1", "e2"];
s.frameSchema.optional = ["normal", "convention", "source"];
s.frameSchema.domains = ["vertex", "face"];

end
