function [divU, rotU, harmU, scalarP, vectorP, plotFields] = hhdecomposition(manifold, U, options)
    % HHDECOMPOSITION Compute Helmholtz-Hodge decomposition of a vector field
    %
    % Syntax:
    %   [divU, rotU, harmU, scalarP, vectorP] = ...
    %       bct.operator.differential.hhdecomposition(manifold, U)
    %   [divU, rotU, harmU, scalarP, vectorP, plotFields] = ...
    %       bct.operator.differential.hhdecomposition(manifold, U, 'Normalize', true)
    %
    % Inputs:
    %   manifold - bct.Manifold object
    %   U        - Vector field [M x 3] defined on faces
    %
    % Name-Value Arguments:
    %   Normalize - If true, returns normalized vector fields for plotting
    %               (default: false)
    %
    % Outputs:
    %   divU     - Divergence-free component [M x 3]
    %   rotU     - Curl-free component [M x 3]
    %   harmU    - Harmonic component [M x 3]
    %   scalarP  - Scalar potential (for curl-free component)
    %   vectorP  - Vector potential (for divergence-free component)
    %   plotFields - Struct with normalized fields (if Normalize=true):
    %                .U     - Original field (normalized)
    %                .divU  - Divergence-free (normalized)
    %                .rotU  - Curl-free (normalized)
    %                .harmU - Harmonic (normalized)
    %
    % Description:
    %   Performs the Helmholtz-Hodge decomposition of a vector field U
    %   into three orthogonal components:
    %     U = divU + rotU + harmU
    %   where:
    %     - divU is divergence-free (solenoidal)
    %     - rotU is curl-free (irrotational/conservative)
    %     - harmU is harmonic (both divergence-free and curl-free)
    %
    %   The decomposition also provides the scalar and vector potentials:
    %     rotU = grad(scalarP)
    %     divU = curl(vectorP)
    %
    % Example:
    %   % Load mesh
    %   data = load('data/mesh/fsaverage_rh_pial.mat');
    %   M = bct.bct.fromMesh(data.V, data.F);
    %   
    %   % Create a complex vector field
    %   [~, e1, e2] = M.computeTangentFrame();
    %   theta = linspace(0, 2*pi, size(M.Faces,1))';
    %   U = cos(theta).*e1 + sin(theta).*e2;
    %   
    %   % Decompose vector field
    %   [divU, rotU, harmU, scalarP, vectorP] = ...
    %       bct.operator.differential.hhdecomposition(M, U);
    %   
    %   % Verify decomposition
    %   U_reconstructed = divU + rotU + harmU;
    %   reconstruction_error = norm(U - U_reconstructed, 'fro');
    %   fprintf('Reconstruction error: %.6e\n', reconstruction_error);
    %
    %   % Get normalized fields for plotting
    %   [divU, rotU, harmU, ~, ~, plotFields] = ...
    %       bct.operator.differential.hhdecomposition(M, U, 'Normalize', true);
    %   
    %   % Visualize components
    %   figure;
    %   C = M.centroid();
    %   subplot(2,2,1); patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %       'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none'); hold on;
    %   quiver3(C(:,1), C(:,2), C(:,3), plotFields.U(:,1), ...
    %           plotFields.U(:,2), plotFields.U(:,3), 0.5, 'r');
    %   title('Original Field'); axis equal;
    %   
    %   subplot(2,2,2); patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %       'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none'); hold on;
    %   quiver3(C(:,1), C(:,2), C(:,3), plotFields.divU(:,1), ...
    %           plotFields.divU(:,2), plotFields.divU(:,3), 0.5, 'b');
    %   title('Divergence-Free Component'); axis equal;
    %   
    %   subplot(2,2,3); patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %       'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none'); hold on;
    %   quiver3(C(:,1), C(:,2), C(:,3), plotFields.rotU(:,1), ...
    %           plotFields.rotU(:,2), plotFields.rotU(:,3), 0.5, 'g');
    %   title('Curl-Free Component'); axis equal;
    %   
    %   subplot(2,2,4); patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %       'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none'); hold on;
    %   quiver3(C(:,1), C(:,2), C(:,3), plotFields.harmU(:,1), ...
    %           plotFields.harmU(:,2), plotFields.harmU(:,3), 0.5, 'm');
    %   title('Harmonic Component'); axis equal;
    
    arguments
        manifold (1,1) bct.Manifold
        U (:,3) double
        options.Normalize (1,1) logical = false
    end
    
    % Validate vector field size matches number of faces
    if size(U, 1) ~= size(manifold.Faces, 1)
        error('bct:hhdecomposition:InvalidVectorFieldSize', ...
              'Vector field U must have %d rows (number of faces)', ...
              size(manifold.Faces, 1));
    end
    
    % Perform Helmholtz-Hodge decomposition
    [divU, rotU, harmU, scalarP, vectorP] = ...
        manifold.DEC.helmholtzHodgeDecomposition(U);
    
    % Normalize vector fields for plotting if requested
    if options.Normalize || nargout > 5
        plotFields.U = normalizerow(U);
        plotFields.divU = normalizerow(divU);
        plotFields.rotU = normalizerow(rotU);
        plotFields.harmU = normalizerow(harmU);
    end
end

function X = normalizerow(X)
    % NORMALIZEROW Normalize each row of a matrix to unit length
    norms = vecnorm(X, 2, 2);
    X = X ./ norms;
    X(~isfinite(X)) = 0;
end
