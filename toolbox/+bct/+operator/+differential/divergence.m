function divU = divergence(manifold, U, options)
    % DIVERGENCE Compute DEC-based divergence of a vector field on a manifold
    %
    % Syntax:
    %   divU = bct.operator.differential.divergence(manifold, U)
    %   divU = bct.operator.differential.divergence(manifold, U, 'Negate', true)
    %
    % Inputs:
    %   manifold - bct.Manifold object
    %   U        - Vector field [M x 3] defined on faces
    %
    % Name-Value Arguments:
    %   Negate   - If true, negates the vector field before computing
    %              divergence (default: false)
    %
    % Outputs:
    %   divU     - Divergence [N x 1] defined on vertices
    %
    % Description:
    %   Computes the divergence of a vector field U using the discrete
    %   exterior calculus (DEC) framework. The divergence is computed on
    %   the vertices of the manifold triangulation.
    %
    %   The negation option is useful when computing divergence of gradient
    %   flows, where U = -∇w represents the flow direction.
    %
    % Example:
    %   % Load mesh
    %   data = load('data/mesh/fsaverage_rh_pial.mat');
    %   M = bct.bct.fromMesh(data.V, data.F);
    %   
    %   % Create signal and compute gradient
    %   w = M.Vertices(:,1);  % x-coordinate as signal
    %   [~, gradW_unit] = bct.operator.differential.gradient(M, w);
    %   
    %   % Compute divergence of negative gradient (flow)
    %   divU = bct.operator.differential.divergence(M, gradW_unit, 'Negate', true);
    %   
    %   % Visualize divergence
    %   figure; patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %                 'FaceVertexCData', divU, 'FaceColor', 'interp');
    %   colorbar; title('Divergence of -∇w');
    
    arguments
        manifold (1,1) bct.Manifold
        U (:,3) double
        options.Negate (1,1) logical = false
    end
    
    % Validate vector field size matches number of faces
    if size(U, 1) ~= size(manifold.Faces, 1)
        error('bct:divergence:InvalidVectorFieldSize', ...
              'Vector field U must have %d rows (number of faces)', ...
              size(manifold.Faces, 1));
    end
    
    % Negate vector field if requested
    if options.Negate
        U = -U;
    end
    
    % Compute divergence using DEC
    divU = manifold.DEC.divergence(U);
    divU = divU(:);
end
