function lights = applyDefaults(grid, ax, hPatch, overlays, style, varargin)
%BCT.UI.MANIFOLD.APPLYDEFAULTS  Apply style spec to existing graphics handles
%
%   lights = bct.ui.manifold.applyDefaults(grid, ax, hPatch, overlays, style)
%
% Inputs
%   grid     - uigridlayout handle (comp.Grid)
%   ax       - uiaxes handle (comp.Ax)
%   hPatch   - patch handle (comp.hPatch)
%   overlays - struct with optional fields: Quiver, Seed, Target
%   style    - struct from bct.ui.manifold.defaults()
%
% Name-Value
%   "Lights" - struct with optional fields: Key, Fill (reuse existing lights)
%
% Output
%   lights.Key, lights.Fill - light handles (created or reused)

    arguments
        grid (1,1) matlab.ui.container.GridLayout
        ax (1,1) matlab.ui.control.UIAxes
        hPatch (1,1)
        overlays (1,1) struct
        style (1,1) struct
    end
    arguments (Repeating)
        varargin
    end

    p = inputParser();
    p.addParameter("Lights", struct("Key",[], "Fill",[]));
    p.parse(varargin{:});
    L = p.Results.Lights;

    % --- Layout
    if isfield(style, "Layout")
        grid.BackgroundColor = style.Layout.GridBackgroundColor;
        grid.Padding = style.Layout.GridPadding;
        grid.RowSpacing = style.Layout.GridRowSpacing;
        grid.ColumnSpacing = style.Layout.GridColumnSpacing;
    end

    % --- Axes
    ax.Color    = style.Axes.Color;
    ax.Visible  = style.Axes.Visible;
    ax.Clipping = style.Axes.Clipping;

    if isprop(ax, "Projection")
        ax.Projection = style.Axes.Projection;
    end

    if ~isempty(style.Axes.AxisMode)
        axis(ax, style.Axes.AxisMode);
    end

    if style.Axes.DisableInteractivity
        disableDefaultInteractivity(ax);
    end
    if style.Axes.HideToolbar && isprop(ax, "Toolbar") && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = "off";
    end

    if style.Axes.LockCamera
        ax.CameraPositionMode  = "manual";
        ax.CameraTargetMode    = "manual";
        ax.CameraUpVectorMode  = "manual";
        ax.CameraViewAngleMode = "manual";
    end

    % --- Patch (do not change geometry ownership)
    set(hPatch, ...
        "EdgeColor",         style.Patch.EdgeColor, ...
        "FaceLighting",      style.Patch.FaceLighting, ...
        "PickableParts",     style.Patch.PickableParts, ...
        "HitTest",           style.Patch.HitTest, ...
        "AmbientStrength",   style.Patch.AmbientStrength, ...
        "DiffuseStrength",   style.Patch.DiffuseStrength, ...
        "SpecularStrength",  style.Patch.SpecularStrength, ...
        "SpecularExponent",  style.Patch.SpecularExponent, ...
        "BackFaceLighting",  style.Patch.BackFaceLighting);

    % --- Overlays (optional handles)
    if isfield(overlays, "Quiver") && ~isempty(overlays.Quiver) && isvalid(overlays.Quiver)
        set(overlays.Quiver, ...
            "Color", style.Overlays.Quiver.Color, ...
            "LineWidth", style.Overlays.Quiver.LineWidth, ...
            "Visible", style.Overlays.Quiver.Visible);
    end
    if isfield(overlays, "Seed") && ~isempty(overlays.Seed) && isvalid(overlays.Seed)
        set(overlays.Seed, ...
            "Marker", style.Overlays.SeedMarker.Marker, ...
            "Color", style.Overlays.SeedMarker.Color, ...
            "LineWidth", style.Overlays.SeedMarker.LineWidth, ...
            "Visible", style.Overlays.SeedMarker.Visible);
    end
    if isfield(overlays, "Target") && ~isempty(overlays.Target) && isvalid(overlays.Target)
        set(overlays.Target, ...
            "Marker", style.Overlays.TargetMarker.Marker, ...
            "Color", style.Overlays.TargetMarker.Color, ...
            "LineWidth", style.Overlays.TargetMarker.LineWidth, ...
            "Visible", style.Overlays.TargetMarker.Visible);
    end

    % --- Lighting
    if style.Lights.ClearExisting
        delete(findall(ax, "Type", "light"));
        L.Key  = [];
        L.Fill = [];
    end

    if isempty(L.Key) || ~isvalid(L.Key)
        L.Key = camlight(ax, char(style.Lights.KeyType));
    else
        camlight(L.Key, char(style.Lights.KeyType));
    end

    if isempty(L.Fill) || ~isvalid(L.Fill)
        L.Fill = camlight(ax, char(style.Lights.FillType));
    else
        camlight(L.Fill, char(style.Lights.FillType));
    end

    if ~isempty(style.Lights.FillColor)
        L.Fill.Color = style.Lights.FillColor;
    end
    if ~isempty(style.Lights.FillPositionScale)
        L.Fill.Position = L.Fill.Position .* style.Lights.FillPositionScale;
    end

    if ~isempty(style.Lights.ShadingModel)
        lighting(ax, char(style.Lights.ShadingModel));
    end

    lights = struct("Key", L.Key, "Fill", L.Fill);
end
