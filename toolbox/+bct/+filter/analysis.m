function coeff = analysis(in, kernelFn)
%BCT.FILTER.ANALYSIS [DEPRECATED] Use bct.filter.applySpectral instead
%   Spectral analysis with kernel
%
% This function is deprecated. Use the new Eigenpairs-based interface:
%   E = domain.FEM().eigenpairs(K);
%   k = bct.kernel.bind(kernelId, params);
%   y = bct.filter.applySpectral(E, x, k);
%
% See also: bct.filter.applySpectral, bct.kernel.bind

    arguments
        in (1,1) bct.Signal
        kernelFn {mustBeA(kernelFn, 'function_handle')}
    end

    warning('bct:filter:Deprecated', ...
        ['bct.filter.analysis is deprecated. Use bct.filter.applySpectral with Eigenpairs.\n' ...
         'See help bct.filter.applySpectral for details.']);

    domain = in.Domain;

    if isa(domain, 'bct.Manifold')
        % Get eigenpairs through FEM
        fem = domain.FEM();
        E = fem.eigenpairs();
        
        % Project to spectral domain and apply kernel
        lambda = E.Values;
        U = E.Vectors;
        coeff0 = U' * (E.MassMatrix * in.Data);
        coeff = kernelFn(lambda) .* coeff0;

    elseif isa(domain, 'bct.Graph')
        G = domain.GSP;
        lambda = G.e;
        coeff0 = gsp_gft(G, in.Data);
        coeff = kernelFn(lambda) .* coeff0;

    else
        error("Unsupported domain for filtering");
    end
end
