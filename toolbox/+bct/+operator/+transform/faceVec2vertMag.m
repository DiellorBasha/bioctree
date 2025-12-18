function vertMag = faceVec2vertMag(manifold, X)
    % FACEVEC2VERTMAG Project face vectors to vertex magnitudes for visualization
    %
    % Syntax:
    %   vertMag = bct.operator.transform.faceVec2vertMag(manifold, X)
    %
    % Inputs:
    %   manifold - bct.Manifold object
    %   X        - Vector field [M x 3] defined on faces
    %
    % Outputs:
    %   vertMag  - Vector magnitudes [N x 1] defined on vertices
    %
    % Description:
    %   Projects a face-based vector field to vertex-based magnitudes
    %   for visualization purposes. Each vector component is averaged
    %   from faces to vertices using accumarray, then the magnitude
    %   is computed at each vertex.
    %
    %   This is useful for coloring vertices by the magnitude of a
    %   vector field that is naturally defined on faces (e.g., gradient,
    %   divergence-free component, curl-free component).
    %
    % Algorithm:
    %   1. For each component (x, y, z), average face values to vertices
    %   2. Compute magnitude: ||V|| = sqrt(Vx^2 + Vy^2 + Vz^2)
    %
    % Example:
    %   % Load mesh
    %   data = load('data/mesh/fsaverage_rh_pial.mat');
    %   M = bct.bct.fromMesh(data.V, data.F);
    %   
    %   % Create signal and compute gradient
    %   w = M.Vertices(:,1);  % x-coordinate as signal
    %   gradW = bct.operator.differential.gradient(M, w);
    %   
    %   % Compute vertex magnitudes for visualization
    %   gradMag = bct.operator.transform.faceVec2vertMag(M, gradW);
    %   
    %   % Visualize
    %   figure; patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %                 'FaceVertexCData', gradMag, 'FaceColor', 'interp');
    %   colorbar; title('Gradient Magnitude');
    %
    %   % Use with Helmholtz-Hodge decomposition
    %   [divU, rotU, harmU] = bct.operator.differential.hhdecomposition(M, gradW);
    %   divU_mag = bct.operator.transform.faceVec2vertMag(M, divU);
    %   rotU_mag = bct.operator.transform.faceVec2vertMag(M, rotU);
    %   harmU_mag = bct.operator.transform.faceVec2vertMag(M, harmU);
    
    arguments
        manifold (1,1) bct.Manifold
        X (:,3) double
    end
    
    % Get mesh dimensions
    Nv = size(manifold.Vertices, 1);
    Nf = size(manifold.Faces, 1);
    F = manifold.Faces;
    
    % Validate vector field size
    if size(X, 1) ~= Nf
        error('bct:faceVec2vertMag:InvalidVectorFieldSize', ...
              'Vector field X must have %d rows (number of faces)', Nf);
    end
    
    % Project each component from faces to vertices (average)
    Vx = accumarray(F(:), repmat(X(:,1), 3, 1), [Nv 1], @mean, 0);
    Vy = accumarray(F(:), repmat(X(:,2), 3, 1), [Nv 1], @mean, 0);
    Vz = accumarray(F(:), repmat(X(:,3), 3, 1), [Nv 1], @mean, 0);
    
    % Compute magnitude at each vertex
    vertMag = sqrt(Vx.^2 + Vy.^2 + Vz.^2);
end
