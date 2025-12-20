function spec = schema()
%BCT.UI.COLOR.SCHEMA  Default ColorSpec structure for v1
%
%   spec = bct.ui.color.schema()
%
% Purpose
%   Returns the default color mapping specification structure.
%
% Outputs
%   spec - struct with fields:
%     Colormap  (string): colormap ID (default: "parula")
%     NColors   (positive integer): number of colors (default: 256)
%     CLim      ([] or [lo hi]): color limits (default: [])
%     NaNColor  (1×3 double): RGB for non-finite values (default: [0.2 0.2 0.2])
%
% See also: bct.ui.color.rgb, bct.ui.color.validate

    spec = struct( ...
        "Colormap", "parula", ...
        "NColors", 256, ...
        "CLim", [], ...
        "NaNColor", [0.2 0.2 0.2] );
end
