classdef ColormapCategory
    % ColormapCategory
    %
    % Semantic classification of colormaps.
    % Used to enforce correctness between data types and visualization.
    %
    % This enum is UI-agnostic and rendering-backend-agnostic.

    enumeration
        Binary        % Logical masks, thresholds
        Scalar        % Continuous scalar fields (>= 0 or arbitrary)
        Diverging     % Signed scalar fields (e.g. eigenmodes)
        Cyclic        % Phase / angular data
        VectorRGB     % Pre-colored RGB data
        Categorical   % Labels / parcels / regions
    end
end
