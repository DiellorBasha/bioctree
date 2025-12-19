function Viz = x2rgbmanifold(x, Manifold, params, opts)
% x2rgbmanifold
%
% Adapter that maps a scalar field defined on a manifold's vertices
% to renderer-ready RGB colors and optional annotations.
%
% Internally delegates scalar→RGB mapping to x2rgb().
%
% INPUTS
% ------
% x        : N×1 numeric scalar field on vertices
% Manifold : struct with fields:
%              - Vertices : N×3 double
%              - N        : number of vertices
% params   : struct (optional)
%              - source : vertex index for source annotation
%              - target : vertex index for target annotation
% opts     : struct (optional)
%              - x2rgbArgs : cell array of name/value args passed to x2rgb
%              - mask      : logical N×1 mask
%              - background: 1×3 RGB color (default [0.6 0.6 0.6])
%
% OUTPUT
% ------
% Viz : struct with fields
%        - rgb
%        - SourcePoint
%        - TargetPoint
%        - meta

    arguments
        x (:,1) double
        Manifold struct
        params struct = struct()
        opts.x2rgbArgs cell = {}
        opts.mask (:,1) logical = []
        opts.background (1,3) double = [0.6 0.6 0.6]
    end

    N = Manifold.N;
    assert(numel(x) == N, ...
        'Input length (%d) must match Manifold.N (%d)', numel(x), N);

    % --- Scalar → RGB (low-level) ---
    rgb = x2rgb(x, opts.x2rgbArgs{:});

    % --- Optional masking ---
    if ~isempty(opts.mask)
        assert(numel(opts.mask) == N, 'Mask size mismatch');
        bg = opts.background;
        rgb(~opts.mask,:) = repmat(bg, nnz(~opts.mask), 1);
    end

    % --- Optional annotations ---
    SourcePoint = [];
    TargetPoint = [];

    if isfield(params, 'source')
        SourcePoint = images.ui.graphics.roi.Point( ...
            Position = Manifold.Vertices(params.source, :));
        SourcePoint.Label = "Source";
    end

    if isfield(params, 'target')
        TargetPoint = images.ui.graphics.roi.Point( ...
            Position = Manifold.Vertices(params.target, :));
        TargetPoint.Label = "Target";
    end

    % --- Pack output ---
    Viz = struct( ...
        'rgb', rgb, ...
        'SourcePoint', SourcePoint, ...
        'TargetPoint', TargetPoint, ...
        'meta', struct( ...
            'nVertices', N, ...
            'background', opts.background, ...
            'x2rgbArgs', {opts.x2rgbArgs} ));

end
