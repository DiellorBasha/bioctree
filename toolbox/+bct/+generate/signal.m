function sig = signal(domain, name, params)
%BCT.GENERATE.SIGNAL
%   Generate a Signal by evaluating a kernel function on a domain axis

    arguments
        domain
        name (1,:) char
        params struct = struct()
    end

    % Fetch registry
    reg = bct.kernel.registry();

    if ~isfield(reg, name)
        error("Unknown kernel '%s'", name);
    end

    entry = reg.(name);

    % Domain axis (THIS is the key abstraction)
    axis = domain.axis;

    % Default params if needed
    if isempty(fieldnames(params)) && isfield(entry,'DefaultParams')
        params = entry.DefaultParams(axis);
    end

    % Evaluate function ON AXIS
    data = entry.Function(axis, params);

    % Ensure column vector
    data = data(:);

    % Wrap as Signal
    sig = bct.Signal( ...
        data, ...
        domain, ...
        domain.displayCoordinateMode, ...
        struct('Generator', name, 'Params', params) );
end
