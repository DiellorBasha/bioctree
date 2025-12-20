function out = synthesis(coeff, domain)
%BCT.FILTER.SYNTHESIS [DEPRECATED] Use bct.filter.applySpectral instead
%   Reconstruct filtered signal from spectral coefficients
%
% This function is deprecated. Use the new Eigenpairs-based interface:
%   E = domain.FEM().eigenpairs(K);
%   k = bct.kernel.bind(kernelId, params);
%   y = bct.filter.applySpectral(E, x, k);
%
% See also: bct.filter.applySpectral, bct.Eigenpairs.reconstruct

    arguments
        coeff (:,:) double
        domain
    end

    warning('bct:filter:Deprecated', ...
        ['bct.filter.synthesis is deprecated. Use bct.filter.applySpectral with Eigenpairs.\n' ...
         'See help bct.filter.applySpectral for details.']);

    if isa(domain, 'bct.Manifold')
        % Get eigenpairs through FEM
        fem = domain.FEM();
        E = fem.eigenpairs();
        U = E.Vectors;
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
