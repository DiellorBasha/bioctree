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

warning('bct:filter:Deprecated', ...
    ['bct.filter.analysis is deprecated. Use bct.filter.applySpectral with Eigenpairs.\n' ...
     'See help bct.filter.applySpectral for details.']);

    arguments
        in (1,1) bct.Signal
        kernelFn (1,1) function_handle
    end

    domain = in.Domain;

    if isa(domain, 'bct.Manifold')
        L = domain.dual;
        U = L.U;
        lambda = L.lambda;
        coeff0 = U' * in.Data;
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
