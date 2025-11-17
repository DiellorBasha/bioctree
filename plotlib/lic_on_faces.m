function lic_face = lic_on_faces(V,F,grad_face, kernel_len_mm, nSteps, rngSeed)
    if nargin<6, rngSeed = 0; end
    if nargin<5, nSteps = 20; end
    if nargin<4, kernel_len_mm = 20; end
    rng(rngSeed);

    m = size(F,1);
    C = (V(F(:,1),:)+V(F(:,2),:)+V(F(:,3),:))/3;
    F2F = face_adjacency(F);

    % unit tangent field per face
    vf = grad_face;
    vf = vf ./ (sqrt(sum(vf.^2,2))+eps);

    % white noise per face
    eta = randn(m,1);

    h = kernel_len_mm / nSteps;             % step size (mm)
    lic_face = zeros(m,1);

    for f0 = 1:m
        acc = 0; wsum = 0;

        % integrate both directions
        for signDir = [-1, +1]
            f = f0; p = C(f0,:);
            for k = 0:nSteps
                % Gaussian kernel along arc-length (centered at 0)
                s = signDir*k*h; w = exp(-0.5*(s/kernel_len_mm)^2);
                acc  = acc + w*eta(f); wsum = wsum + w;

                % step
                v = vf(f,:); if signDir<0, v = -v; end
                p_try = p + h*v;
                [f2, p2] = step_across_face(p, p_try, V, F, f, F2F);
                if f2==0, break; end
                p = p2; f = f2;
            end
        end

        lic_face(f0) = acc/max(wsut(1,wsum),eps);
    end

    % normalize to 0..1 for display
    lic_face = (lic_face - min(lic_face)) / max(eps, (max(lic_face)-min(lic_face)));
end
