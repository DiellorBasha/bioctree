function plotGeodesicDistance(D_sorted, region_names, region_boundaries, hemisphere_label)
% PLOT_GEODESIC_DISTANCE_MATRIX_BY_REGION
%   Visualizes a geodesic distance matrix sorted by atlas region.
%
% Inputs:
%   D_sorted         - NxN geodesic distance matrix, already sorted by region
%   region_names     - 1xR cell array of region labels
%   region_boundaries- 1x(R+1) array indicating start/end index of each region
%   hemisphere_label - string (e.g., 'Left Hemisphere') for plot title
%
% Example:
%   plot_geodesic_distance_matrix_by_region(Dlh_sorted, region_names, region_boundaries, 'Left Hemisphere');

    figure;
    imagesc(D_sorted);
    colormap('hot');
    colorbar;
    axis square;
    title(['Geodesic Distance Matrix (' hemisphere_label ') Grouped by DK Regions']);

    % Add region boundary lines
    hold on;
    for b = region_boundaries
        xline(b + 0.5, 'k', 'LineWidth', 0.5);
        yline(b + 0.5, 'k', 'LineWidth', 0.5);
    end

    % Compute tick positions for region labels
    tick_pos = 0.5 * (region_boundaries(1:end-1) + region_boundaries(2:end));
    set(gca, 'XTick', tick_pos, 'XTickLabel', region_names, ...
             'YTick', tick_pos, 'YTickLabel', region_names);
    xtickangle(45);
end
