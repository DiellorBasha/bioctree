figure;
patch( ...
    'Faces', F, ...
    'Vertices', V, ...
    'FaceVertexCData', FaceRGB, ...
    'FaceColor', 'flat', ...
    'EdgeColor', 'none' );

axis equal off
lighting flat
title('DEC Gradient (face-based, diagnostic)');

%%
wMin = prctile(w, 5);
wMax = prctile(w, 95);
wN   = (w - wMin) ./ (wMax - wMin);
wN   = min(max(wN, 0), 1);
wN   = wN(:);   % CRITICAL

bgColor    = [0.4 0.4 0.4];   % light gray cortex
%patchColor = [0.2 0.4 1.0];   % blue signal color
%wRGB = wN .* patchColor;   % [Nv × 3]
nColors = 256;
cmap    = turbo(nColors);
cmap = hot(nColors);
idx  = round(wN * (nColors-1)) + 1;   % indices in [1, nColors]
wRGB = cmap(idx, :);                 % [Nv × 3]
cmap = turbo(256);          % or parula, viridis, hot, etc.
idx  = max(1, round(w*255));

rgb = repmat(bgColor, length(w), 1);
mask = w > 0;
rgb(mask,:) = cmap(idx(mask),:);
wRGB=rgb;
figure;

patch( ...
    'Faces', F, ...
    'Vertices', V, ...
    'FaceColor', bgColor, ...
    'EdgeColor', 'none' );

axis equal off
hold on

patch( ...
    'Faces', F, ...
    'Vertices', V, ...
    'FaceVertexCData', wRGB, ...
    'FaceColor', 'interp', ...
    'EdgeColor', 'none', ...
    'FaceAlpha', 'interp', ...
    'FaceVertexAlphaData', wN );
lighting gouraud
camlight headlight
material dull