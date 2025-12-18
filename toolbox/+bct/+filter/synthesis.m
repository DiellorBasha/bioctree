function out = synthesis(coeff, domain)
%BCT.FILTER.SYNTHESIS
%   Reconstruct filtered signal from spectral coefficients

    arguments
        coeff (:,:) double
        domain
    end

    if isa(domain, 'bct.Manifold')
        U = domain.dual.U;
        data = U * coeff;

    elseif isa(domain, 'bct.Graph')
        data = gsp_igft(domain.GSP, coeff);

    else
        error("Unsupported domain for synthesis");
    end

    out = bct.Signal( ...
        data, ...
        domain, ...
        bct.enum.DomainLocation.Vertex, ...
        struct('Operator','filter_synthesis') );
end
