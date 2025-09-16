function [W_geo_lh, W_geo_rh, V_lh, V_rh] = computeGeodesicWeightMatrix(data, sigma)
% computeGeodesicWeightMatrixBothHemispheres - Computes geodesic distance-based weight matrices
% for both hemispheres using Dijkstra's algorithm and converts them to
% geodesic-aware weights using a Gaussian kernel.
%
% Syntax:
%   [W_geo_lh, W_geo_rh, V_lh, V_rh, lh_idx, rh_idx] = computeGeodesicWeightMatrixBothHemispheres(data, sigma)
%
% Inputs:
%   data  - Struct containing:
%           - data.anat.Vertices  : N×3 vertex coordinates
%           - data.anat.Faces     : M×3 face indices (not used here, but often needed)
%           - data.anat.VertConn  : N×N sparse binary adjacency matrix
%   sigma - Scalar for Gaussian kernel width in mm (optional, default: 3)
%
% Outputs:
%   W_geo_lh - Geodesic-aware weight matrix for left hemisphere
%   W_geo_rh - Geodesic-aware weight matrix for right hemisphere
%   V_lh     - Vertex coordinates of left hemisphere
%   V_rh     - Vertex coordinates of right hemisphere
%   lh_idx   - Vertex indices for left hemisphere
%   rh_idx   - Vertex indices for right hemisphere

    if nargin < 2
        sigma = 3;  % Default Gaussian kernel width in mm
    end

    % Step 0: Extract inputs
    V = data.anat.Vertices;
    VertConn = data.anat.VertConn;
    N = size(VertConn, 1);

    if size(V, 2) ~= 3
        V = V';  % Ensure V is N×3
    end

    % Step 1: Compute edge weights (Euclidean distances between neighbors)
    [i, j] = find(VertConn);
    edge_lengths = sqrt(sum((V(i,:) - V(j,:)).^2, 2));
    W = sparse(i, j, edge_lengths, N, N);

    % Step 2: Build graph and find hemispheric components
    Gmat = graph(W);
    bins = conncomp(Gmat);  % Component labels

    lh_idx = find(bins == 1);
    rh_idx = find(bins == 2);

    % Step 3: Compute distances and weights for LH
    G_lh = subgraph(Gmat, lh_idx);
    D_lh = distances(G_lh, 'Method','positive');  % Geodesic distance matrix
    W_geo_lh = exp(-D_lh.^2 / (2 * sigma^2));
    W_geo_lh(D_lh == 0) = 0;  % Remove self-weight
    V_lh = V(lh_idx, :);

    % Step 4: Compute distances and weights for RH
    G_rh = subgraph(Gmat, rh_idx);
    D_rh = distances(G_rh);
    W_geo_rh = exp(-D_rh.^2 / (2 * sigma^2));
    W_geo_rh(D_rh == 0) = 0;
    V_rh = V(rh_idx, :);

end
