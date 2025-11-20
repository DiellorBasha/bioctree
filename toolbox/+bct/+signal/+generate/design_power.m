```matlab
function P = design_power(f, spec)
    switch lower(spec.type)
        case 'narrowband'
            P = exp(-0.5 * ((f - spec.f0)/spec.bw).^2);
        case 'flat'
            P = ones(size(f));
        case 'powerlaw'
            P = (f + eps).^(-spec.alpha);
        case 'bandpass'
            P = double(f >= spec.fmin & f <= spec.fmax);
        otherwise
            error('Unknown spec.type');
    end
    % normalize
    s = sum(P);
    if s>0, P = P / s; end
end

```
