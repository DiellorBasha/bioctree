function writeColormapAtlasPNG(outPng, mapNames, lutSize, csvDir)
% writeColormapAtlasPNG  Create a LUT atlas PNG (lutSize × numMaps) from
% built-in MATLAB colormaps + CSV colormaps.
%
% outPng   : output filename, e.g. fullfile(pwd,"colormaps_atlas.png")
% mapNames : string array, e.g. ["parula","turbo","viridis","inferno","plasma"]
% lutSize  : e.g. 256
% csvDir   : directory containing *_colormap.csv files

    if nargin < 3 || isempty(lutSize), lutSize = 256; end
    if nargin < 4 || isempty(csvDir)
        error("csvDir is required (path to your Colormaps_MATLAB CSV folder).");
    end

    mapNames = string(mapNames);
    numMaps = numel(mapNames);

    atlas = zeros(numMaps, lutSize, 3, "single");   % rows = maps, cols = LUT samples

    for i = 1:numMaps
        name = mapNames(i);
        cmap = getMapUnified(name, lutSize, csvDir);  % lutSize×3 in [0,1]
        atlas(i,:,:) = reshape(single(cmap), [1, lutSize, 3]);
    end

    atlas8 = uint8(round(255 * max(min(atlas, 1), 0)));
    imwrite(atlas8, outPng);

    fprintf("Wrote atlas PNG: %s\n", outPng);
    fprintf("Atlas dimensions: width=%d, height=%d\n", lutSize, numMaps);
    fprintf("Row indices (0-based, for your TSL COLORMAPINDEX):\n");
    for i = 1:numMaps
        fprintf("  %d: %s\n", i-1, mapNames(i));
    end
end


function cmap = getMapUnified(name, n, csvDir)
% getMapUnified  Return an n×3 colormap in [0,1].
% Preference order:
%  1) built-in MATLAB colormap if name is supported
%  2) CSV colormap file in csvDir: <name>_colormap.csv
%
% Also supports simple aliases (e.g., "coolwarm" -> "bentcoolwarm" CSV).

    name = lower(string(name));

    % ---- Aliases (adjust to your naming preferences) ----
    % Your folder contains bentcoolwarm_colormap.csv, not coolwarm_colormap.csv
    if name == "coolwarm"
        name = "bentcoolwarm";
    end

    % ---- Built-in colormaps (Pattern 1) ----
    % Add/remove entries as desired.
    switch name
        case "parula"
            cmap = parula(n);
            return
        case "turbo"
            cmap = turbo(n);
            return
        case "jet"
            cmap = jet(n);
            return
        case "hot"
            cmap = hot(n);
            return
        case "cool"
            cmap = cool(n);
            return
        case "spring"
            cmap = spring(n);
            return
        case "summer"
            cmap = summer(n);
            return
        case "autumn"
            cmap = autumn(n);
            return
        case "winter"
            cmap = winter(n);
            return
        case "gray"
            cmap = gray(n);
            return
        case "bone"
            cmap = bone(n);
            return
        case "copper"
            cmap = copper(n);
            return
        case "pink"
            cmap = pink(n);
            return
        otherwise
            % fall through to CSV loader
    end

    % ---- CSV colormaps (Pattern 2) ----
    csvFile = fullfile(csvDir, name + "_colormap.csv");
    if ~isfile(csvFile)
        error("Colormap '%s' not built-in and CSV not found: %s", name, csvFile);
    end

    base = readmatrix(csvFile);

    % Validate shape
    if size(base,2) < 3
        error("CSV must have at least 3 columns (RGB): %s", csvFile);
    end
    base = base(:,1:3);

    % Normalize if CSV is in 0..255
    if max(base, [], "all") > 1.5
        base = base / 255;
    end

    % Clamp for safety
    base = max(min(base, 1), 0);

    % Resample to n entries (handles CSV of arbitrary length)
    L = size(base,1);
    x0 = linspace(0, 1, L);
    x1 = linspace(0, 1, n);
    cmap = interp1(x0, base, x1, "linear");

    % Final clamp
    cmap = max(min(cmap, 1), 0);
end
