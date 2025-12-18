function coeff = analysis(in, kernelFn)
%BCT.FILTER.ANALYSIS
%   Spectral analysis with kernel

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
