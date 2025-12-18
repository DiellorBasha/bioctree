function curlU = curl(manifold, U, options)
    % CURL Compute DEC-based curl of a vector field on a manifold
    %
    % Syntax:
    %   curlU = bct.operator.differential.curl(manifold, U)
    %   curlU = bct.operator.differential.curl(manifold, U, 'Negate', true)
    %
    % Inputs:
    %   manifold - bct.Manifold object
    %   U        - Vector field [M x 3] defined on faces
    %
    % Name-Value Arguments:
    %   Negate   - If true, negates the vector field before computing
    %              curl (default: false)
    %
    % Outputs:
    %   curlU    - Curl (scalar) [N x 1] defined on vertices
    %
    % Description:
    %   Computes the curl of a vector field U using the discrete
    %   exterior calculus (DEC) framework. On a 2D manifold embedded
    %   in 3D, the curl is a scalar field representing the normal
    %   component of the curl vector.
    %
    %   The curl measures the rotation or circulation of the vector
    %   field around each vertex.
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
    %   % Compute curl of gradient (should be near zero)
    %   curlU = bct.operator.differential.curl(M, gradW_unit);
    %   
    %   % Visualize curl
    %   figure; patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %                 'FaceVertexCData', curlU, 'FaceColor', 'interp');
    %   colorbar; title('Curl of ∇w');
    %
    %   % Create rotating vector field
    %   [~, e1, e2] = M.computeTangentFrame();
    %   theta = linspace(0, 2*pi, size(M.Faces,1))';
    %   U_rot = cos(theta).*e1 + sin(theta).*e2;
    %   curlU_rot = bct.operator.differential.curl(M, U_rot);
    %   figure; patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %                 'FaceVertexCData', curlU_rot, 'FaceColor', 'interp');
    %   colorbar; title('Curl of Rotating Field');
    
    arguments
        manifold (1,1) bct.Manifold
        U (:,3) double
        options.Negate (1,1) logical = false
    end
    
    % Validate vector field size matches number of faces
    if size(U, 1) ~= size(manifold.Faces, 1)
        error('bct:curl:InvalidVectorFieldSize', ...
              'Vector field U must have %d rows (number of faces)', ...
              size(manifold.Faces, 1));
    end
    
    % Negate vector field if requested
    if options.Negate
        U = -U;
    end
    
    % Compute curl using DEC
    curlU = manifold.DEC.curl(U);
    curlU = curlU(:);
end
