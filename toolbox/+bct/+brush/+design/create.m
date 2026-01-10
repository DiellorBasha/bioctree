function designer = create(category, brushType, manifold, params, time)
%BCT.BRUSH.DESIGN.CREATE  Create interactive brush designer
%
%   designer = bct.brush.design.create(category, type, manifold, params)
%   designer = bct.brush.design.create(category, type, manifold, params, time)
%
% Creates a BrushDesigner object for interactive parameter manipulation
% and kernel evaluation before finalizing brush weights.
%
% Inputs:
%   category  - 'patch', 'trajectory', or 'time'
%   type      - Brush type name
%   manifold  - bct.Manifold object
%   params    - Parameter struct
%   time      - bct.Time object (for time category)
%
% Returns:
%   designer  - BrushDesigner object with methods:
%               - setParameter(name, value)
%               - evaluateKernel() / evaluateKernel(lambda_values)
%               - plotKernelResponse()
%               - preview()
%               - finalize()
%
% Example - Design spectral heat brush with parameter tuning:
%   B = bct.bct.fromMesh(V, F);
%   
%   % Create designer
%   designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
%       struct('source', 100, 'kernel', 'heat', 'tau', 0.1));
%   
%   % Evaluate kernel on Lambda axis
%   H = designer.evaluateKernel();
%   designer.plotKernelResponse();
%   
%   % Adjust tau to get more diffusion
%   designer.setParameter('tau', 0.25);
%   H_new = designer.evaluateKernel();
%   designer.plotKernelResponse();
%   
%   % Preview spatial pattern
%   designer.preview();
%   
%   % Finalize
%   w = designer.finalize();
%
% Example - Gaussian bandpass on Lambda:
%   designer = bct.brush.design.create('patch', 'spectral', B.Manifold, ...
%       struct('source', 500, 'kernel', 'gaussian', 'center', 100, 'bandwidth', 30));
%   
%   % Preview spectral response
%   designer.plotKernelResponse();
%   
%   % Adjust bandwidth
%   designer.setParameter('bandwidth', 50);
%   designer.plotKernelResponse();
%   
%   w = designer.finalize();
%
% Example - Time-varying spectral brush:
%   designer = bct.brush.design.create('time', 'spectral', B.Manifold, ...
%       struct('source', 200, 'kernel', 'heat', 'tau', 0.15), B.Time);
%   
%   % Evaluate kernel at first time point
%   H = designer.evaluateKernel();
%   
%   % Change tau
%   designer.setParameter('tau', 0.3);
%   H_new = designer.evaluateKernel();
%   
%   % Preview at t=50
%   designer.preview('TimeIndex', 50);
%   
%   w = designer.finalize();  % [N×T]
%
% See also: bct.brush.design.BrushDesigner, bct.brush.design.brush

arguments
    category (1,:) char
    brushType (1,:) char
    manifold (1,1) bct.Manifold
    params struct
    time = []
end

% Create designer
designer = bct.brush.design.BrushDesigner(category, brushType, manifold, params, time);

end
