function [gradW, gradW_unit, amplitude, phase] = gradient(manifold, w)
    % GRADIENT Compute DEC-based gradient of a signal on a manifold
    %
    % Syntax:
    %   gradW = bct.operator.differential.gradient(manifold, w)
    %   [gradW, gradW_unit] = bct.operator.differential.gradient(manifold, w)
    %   [gradW, gradW_unit, amplitude, phase] = bct.operator.differential.gradient(manifold, w)
    %
    % Inputs:
    %   manifold - bct.Manifold object
    %   w        - Signal vector [N x 1] defined on vertices
    %
    % Outputs:
    %   gradW      - Gradient vectors [M x 3] on faces
    %   gradW_unit - Unit gradient vectors [M x 3] (normalized)
    %   amplitude  - Gradient amplitude [M x 1] in tangent frame
    %   phase      - Gradient phase [M x 1] in tangent frame (radians)
    %
    % Description:
    %   Computes the gradient of a scalar signal w using the discrete
    %   exterior calculus (DEC) framework. The gradient is computed on
    %   the faces of the manifold triangulation.
    %
    %   When amplitude and phase are requested, the gradient is decomposed
    %   into the tangent frame {e1, e2} of each face:
    %     gx = gradW · e1
    %     gy = gradW · e2
    %     amplitude = sqrt(gx^2 + gy^2)
    %     phase = atan2(gy, gx)
    %
    % Example:
    %   % Load mesh
    %   data = load('data/mesh/fsaverage_rh_pial.mat');
    %   M = bct.bct.fromMesh(data.V, data.F);
    %   
    %   % Create signal
    %   w = M.Vertices(:,1);  % x-coordinate as signal
    %   
    %   % Compute gradient
    %   [gradW, gradW_unit] = bct.operator.differential.gradient(M, w);
    %   
    %   % Visualize gradient magnitude
    %   gradMag = vecnorm(gradW, 2, 2);
    %   figure; patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %                 'FaceVertexCData', gradMag, 'FaceColor', 'flat');
    %   colorbar; title('Gradient Magnitude');
    %
    %   % Compute tangent frame decomposition
    %   [~, ~, amplitude, phase] = bct.operator.differential.gradient(M, w);
    %   figure; patch('Faces', M.Faces, 'Vertices', M.Vertices, ...
    %                 'FaceVertexCData', phase, 'FaceColor', 'flat');
    %   colormap hsv; colorbar; title('Gradient Phase');
    
    arguments
        manifold (1,1) bct.Manifold
        w (:,1) double
    end
    
    % Validate signal size matches number of vertices
    if numel(w) ~= size(manifold.Vertices, 1)
        error('bct:gradient:InvalidSignalSize', ...
              'Signal w must have length equal to number of vertices (%d)', ...
              size(manifold.Vertices, 1));
    end
    
    % Compute gradient using DEC
    gradW = manifold.DEC.gradient(w);
    
    % Compute normalized gradient if requested
    if nargout > 1
        gradW_unit = gradW ./ vecnorm(gradW, 2, 2);
        gradW_unit(~isfinite(gradW_unit)) = 0;
    end
    
    % Compute tangent frame decomposition if requested
    if nargout > 2
        % Get tangent frame
        [~, e1, e2] = manifold.computeTangentFrame();
        
        % Project gradient onto tangent basis
        gx = sum(gradW .* e1, 2);
        gy = sum(gradW .* e2, 2);
        
        % Compute amplitude and phase
        amplitude = hypot(gx, gy);
        phase = atan2(gy, gx);
    end
end
