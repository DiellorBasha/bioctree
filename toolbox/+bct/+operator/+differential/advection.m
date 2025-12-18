function advW = advection(manifold, U, gradW)
    % ADVECTION Compute advection of a gradient field along a vector field
    %
    % Syntax:
    %   advW = bct.operator.differential.advection(manifold, U, gradW)
    %
    % Inputs:
    %   manifold - bct.Manifold object
    %   U        - Vector field [M x 3] defined on faces (flow field)
    %   gradW    - Gradient field [M x 3] defined on faces
    %
    % Outputs:
    %   advW     - Advection [N x 1] defined on vertices
    %
    % Description:
    %   Computes the advection of a gradient field gradW along a vector
    %   field U. The advection represents the directional derivative of
    %   the signal in the direction of the flow field U.
    %
    %   The computation is performed on faces and then distributed to
    %   vertices using area-weighted averaging:
    %     1. Compute face-wise advection: advW_face = U · gradW
    %     2. Distribute to vertices using accumarray
    %     3. Average by face count per vertex
    %
    % Example:
    %   % Load mesh
    %   data = load('data/mesh/fsaverage_rh_pial.mat');
    %   M = bct.bct.fromMesh(data.V, data.F);
    %   
    %   % Create signal and compute gradient
    %   w = M.Vertices(:,1);  % x-coordinate as signal
    %   [gradW, gradW_unit] = bct.operator.differential.gradient(M, w);
    %   
    %   % Define flow field (negative gradient = downhill flow)
    %   U = -gradW_unit;
    %   
    %   % Compute advection
    %   advW = bct.operator.differential.advection(M, U, gradW);
    %   
    %   % Visualize advection
    %   figure; patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %                 'FaceVertexCData', advW, 'FaceColor', 'interp');
    %   colorbar; title('Advection U·∇w');
    
    arguments
        manifold (1,1) bct.Manifold
        U (:,3) double
        gradW (:,3) double
    end
    
    % Get mesh dimensions
    Nv = size(manifold.Vertices, 1);
    Nf = size(manifold.Faces, 1);
    F = manifold.Faces;
    
    % Validate vector field sizes
    if size(U, 1) ~= Nf
        error('bct:advection:InvalidVectorFieldSize', ...
              'Vector field U must have %d rows (number of faces)', Nf);
    end
    
    if size(gradW, 1) ~= Nf
        error('bct:advection:InvalidGradientSize', ...
              'Gradient field gradW must have %d rows (number of faces)', Nf);
    end
    
    % Compute advection on faces (memory safe)
    advW_face = sum(U .* gradW, 2);
    advW_face = advW_face(:);
    
    % Distribute face values to vertices using accumarray
    advW = accumarray(F(:), repmat(advW_face, 3, 1), [Nv 1], @sum, 0);
    count = accumarray(F(:), 1, [Nv 1], @sum, 0);
    
    % Average by face count per vertex
    advW = advW ./ count;
    advW(~isfinite(advW)) = 0;
end
