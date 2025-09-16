function [X, x, t] = generateRippleLine(Nx, T, f, lambda, alpha, x0)
% generateRippleLine  Traveling ripple on a 1D line.
% X(j,ti) = sin(2π f t - k x) * exp(-alpha*|x-x0|)
% Inputs: Nx (#spatial), T (#time), f (Hz), lambda (spatial), alpha (decay), x0 (center)
% Outputs: X [Nx x T], x [Nx x 1], t [1 x T]

    if nargin < 1 || isempty(Nx), Nx = 128; end
    if nargin < 2 || isempty(T),  T  = 256; end
    if nargin < 3 || isempty(f),  f  = 3;   end
    if nargin < 4 || isempty(lambda), lambda = 16; end
    if nargin < 5 || isempty(alpha), alpha = 0.02; end
    if nargin < 6 || isempty(x0),    x0 = 0; end

    x = linspace(-64, 64, Nx).';
    t = linspace(0, 1, T);
    k = 2*pi/lambda;

    X = zeros(Nx, T);
    for ti = 1:T
        X(:,ti) = sin(2*pi*f*t(ti) - k*x) .* exp(-alpha*abs(x - x0));
    end
end
