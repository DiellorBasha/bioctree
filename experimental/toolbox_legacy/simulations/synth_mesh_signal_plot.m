function synth_mesh_signal_plot(surfaceMesh, X, X_sum, info, opts)
% synth_mesh_signal_plot - Visualize multi-band mesh signal synthesis results
%
% Creates comprehensive visualizations of synthesized multi-band signals
% on triangular meshes, including spectral overlays and spatial patterns.
%
% Syntax:
%   synth_mesh_signal_plot(surfaceMesh, X, X_sum, info)
%   synth_mesh_signal_plot(surfaceMesh, X, X_sum, info, opts)
%
% Inputs:
%   surfaceMesh - MATLAB triangulation or surfaceMesh object
%   X           - {nBands×1} cell array of signals from synth_mesh_5band
%   X_sum       - [N×1] summed signal from synth_mesh_5band
%   info        - Structure from synth_mesh_5band with fields:
%                 .f0s, .Pdes, .FreqBands, .P_sum, .f_range
%   opts        - (optional) Structure with fields:
%                 .show_spectrum    - Show spectral overlay (default: true)
%                 .show_individual  - Show each band on mesh (default: true)
%                 .show_sum_mesh    - Show summed signal on mesh (default: true)
%                 .show_sum_spectrum - Show sum spectrum (default: true)
%
% Outputs:
%   None (creates figures)
%
% Notes:
%   - Requires x2rgb helper function for vertex coloring
%   - Creates multiple figures if all visualization options enabled
%
% Example:
%   [U, lam, K, M] = meshFourier(mesh, 600);
%   d = full(diag(M));
%   [X, X_sum, info] = synth_mesh_5band(U, lam, d);
%   synth_mesh_signal_plot(mesh, X, X_sum, info);
%
% See also: synth_mesh_5band, synth_mesh_signal, meshFourier

% Parse options
if nargin < 5 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'show_spectrum'),     opts.show_spectrum = true; end
if ~isfield(opts, 'show_individual'),   opts.show_individual = true; end
if ~isfield(opts, 'show_sum_mesh'),     opts.show_sum_mesh = true; end
if ~isfield(opts, 'show_sum_spectrum'), opts.show_sum_spectrum = true; end

% Convert to surfaceMesh if needed
if ~isa(surfaceMesh, 'matlab.graphics.chart.primitive.Surface')
    if isstruct(surfaceMesh) && isfield(surfaceMesh, 'Vertices')
        mesh_obj = surfaceMesh;
    elseif isa(surfaceMesh, 'triangulation')
        mesh_obj = surfaceMesh(surfaceMesh.Points, surfaceMesh.ConnectivityList);
    else
        mesh_obj = surfaceMesh;  % assume already correct type
    end
end

nBands = length(X);

% 1) Plot spectra overlay
if opts.show_spectrum
    figure('Name', 'Multi-band Spectral Overlay');
    clf; hold on;
    for i = 1:nBands
        [fs, idx] = sort(info.FreqBands{i});
        plot(fs, info.Pdes{i}(idx), '.-', 'LineWidth', 1.5);
    end
    grid on;
    xlabel('Spatial frequency (cycles/mm)');
    ylabel('Power');
    title('Narrowband designed spectra (long → short wavelengths)');
    legend(arrayfun(@(c) sprintf('f0=%.4f', c), info.f0s, 'uni', 0), ...
           'Location', 'best');
    set(gca, 'FontSize', 10);
end

% 2) Show each band on the mesh
if opts.show_individual
    for i = 1:nBands
        xrec = X{i};
        RGB = x2rgb(xrec);
        
        figure('Name', sprintf('Band %d (f0=%.4f)', i, info.f0s(i)));
        mesh_obj.VertexColors = RGB;
        surfaceMeshShow(mesh_obj);
        axis image off;
        title(sprintf('Narrowband ~ f0=%.4f cyc/mm (bw=%.4f)', ...
                      info.f0s(i), info.bw_frac * info.f0s(i)));
    end
end

% 3) Show summed signal on mesh
if opts.show_sum_mesh
    RGB_sum = x2rgb(X_sum);
    
    figure('Name', 'Multi-band Sum');
    mesh_obj.VertexColors = RGB_sum;
    surfaceMeshShow(mesh_obj);
    axis image off;
    title(sprintf('Sum of %d narrowband signals', nBands));
end

% 4) Show spectrum of summed signal
if opts.show_sum_spectrum
    [freq, idx] = sort(sqrt(info.FreqBands{1}));  % assumes all have same freq vector
    
    figure('Name', 'Sum Signal Spectrum');
    plot(freq, info.P_sum(idx), '.-', 'LineWidth', 1.5);
    grid on;
    xlabel('Spatial frequency (cycles/mm)');
    ylabel('Power');
    title('Spectrum of summed signal');
    set(gca, 'FontSize', 10);
end

end
