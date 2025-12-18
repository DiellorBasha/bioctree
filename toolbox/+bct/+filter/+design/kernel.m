function g = kernel(kernelName, params, axis)
%BCT.FILTER.DESIGN.KERNEL
%   Design a spectral kernel using the kernel registry
%
%   Inputs:
%     kernelName : char / string
%     params     : struct of parameters
%     axis       : spectral axis (e.g. Lambda.lambda)
%
%   Output:
%     g          : function handle g(lambda)

    arguments
        kernelName (1,:) char
        params struct
        axis (:,1) double
    end

    % Get registry
    reg = bct.kernel.registry();

    if ~isfield(reg, kernelName)
        error("bct:filter:design:UnknownKernel", ...
              "Unknown kernel '%s'", kernelName);
    end

    k = reg.(kernelName);

    % Validate parameters
    bct.kernel.validate(kernelName, params, axis);

    % Create kernel function
    g = k.Function(params);

end
