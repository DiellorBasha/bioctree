function D = dictionary()
%BCT.KERNEL.DICTIONARY  Pure function handle registry
%
%   D = bct.kernel.dictionary()
%
% Returns a dictionary mapping kernel names to pure function handles.
% Each function handle is a pure, stateless function that can be directly
% applied to data.
%
% Integration with bct.kernel package:
%   - Uses names from bct.kernel.registry()
%   - Provides lightweight access to kernel functions
%   - No metadata, no UI dependencies, just pure math
%
% Usage:
%   D = bct.kernel.dictionary();
%   
%   % Get a kernel function
%   gaussian = D("Gaussian");
%   y = gaussian(x, mu, sigma);
%   
%   % List available kernels
%   kernelNames = keys(D);
%   
%   % Iterate over all kernels
%   for name = keys(D)
%       f = D(name);
%       % Use f...
%   end
%
% See also: bct.kernel.registry, bct.kernel.list, bct.kernel.get

    D = dictionary();

    %% =========================================================
    % BASIC SMOOTHING KERNELS
    %% =========================================================

    % Heat kernel (exponential decay)
    D("Heat") = @(x, tau) exp(-tau .* x);

    % Gaussian
    D("Gaussian") = @(x, mu, sigma) ...
        exp(-(x - mu).^2 ./ (2*sigma.^2));

    % Laplacian (double exponential)
    D("Laplacian") = @(x, mu, b) ...
        exp(-abs(x - mu) ./ b);

    % Cauchy / Lorentzian
    D("Cauchy") = @(x, mu, gamma) ...
        1 ./ (1 + ((x - mu)./gamma).^2);

    %% =========================================================
    % WAVELET / OSCILLATORY KERNELS
    %% =========================================================

    % Ricker wavelet (Classical Mexican Hat)
    D("Ricker") = @(x, sigma) ...
        (1 - (x.^2 ./ sigma^2)) .* exp(-x.^2 ./ (2*sigma^2));

    % Spectral Mexican Hat (GSP-style)
    D("SpectralMexicanHat") = @(x, tau) ...
        x .* exp(-tau .* x);

    % Morlet wavelet
    D("Morlet") = @(x, mu, sigma, omega) ...
        exp(-(x-mu).^2./(2*sigma.^2)) .* exp(1i*omega.*(x-mu));

    % Gabor
    D("Gabor") = @(x, mu, sigma, f0) ...
        exp(-(x-mu).^2./(2*sigma.^2)) .* cos(2*pi*f0*(x-mu));

    %% =========================================================
    % ORTHOGONAL BASIS FUNCTIONS
    %% =========================================================

    % Hermite functions (quantum harmonic oscillator eigenstates)
    % True continuous analogue of increasing complexity
    % n = order (0=Gaussian ground state, higher=more oscillations)
    D("Hermite") = @(x, n) ...
        (1 ./ sqrt((2.^n).*factorial(n).*sqrt(pi))) .* ...
        hermiteH(n, x) .* exp(-x.^2 / 2);

    % Meyer wavelet (frequency-domain defined)
    % Infinitely smooth, compact in frequency, ideal spectral filter
    % Apply on λ or frequency axis
    D("MeyerHat") = @(w) meyerFrequencyResponse(w);

    %% =========================================================
    % BAND-PASS / FILTER SHAPES
    %% =========================================================

    % Difference of Gaussians (DoG)
    D("DoG") = @(x, tau1, tau2) ...
        exp(-tau1 .* x) - exp(-tau2 .* x);

    % Box / Rectangular
    D("Boxcar") = @(x, center, width) ...
        double(abs(x - center) <= width/2);

    % Triangle
    D("Triangle") = @(x, center, width) ...
        max(0, 1 - abs(x - center)/(width/2));

    % Raised cosine
    D("RaisedCosine") = @(x, x1, x2) ...
        0.5 * (1 + cos(pi*(x-x1)/(x2-x1))) .* (x >= x1 & x <= x2);

    %% =========================================================
    % WINDOW FUNCTIONS
    %% =========================================================

    % Hann window
    D("Hann") = @(t, T) ...
        0.5 * (1 - cos(2*pi*t/T));

    % Hamming window
    D("Hamming") = @(t, T) ...
        0.54 - 0.46*cos(2*pi*t/T);

    % Tukey window
    D("Tukey") = @(t, T, alpha) ...
        tukeywin(numel(t), alpha);

    %% =========================================================
    % IMPULSE / INDICATOR FUNCTIONS
    %% =========================================================

    % Delta / Kronecker
    D("Delta") = @(x, center) ...
        double(x == center);

    % Indicator / characteristic function
    D("Indicator") = @(x, xmin, xmax) ...
        double(x >= xmin & x <= xmax);

    % Constant
    D("Constant") = @(x, value) ...
        value * ones(size(x));

    %% =========================================================
    % NONLINEARITIES
    %% =========================================================

    % ReLU
    D("ReLU") = @(x) max(0, x);

    % Leaky ReLU
    D("LeakyReLU") = @(x, alpha) ...
        max(alpha*x, x);

    % Sigmoid
    D("Sigmoid") = @(x) ...
        1 ./ (1 + exp(-x));

    % Hyperbolic tangent
    D("Tanh") = @(x) tanh(x);

    % Softplus
    D("Softplus") = @(x) log(1 + exp(x));

    %% =========================================================
    % DISTANCE-BASED MAPS
    %% =========================================================

    % Inverse distance
    D("InverseDistance") = @(d, p) ...
        1 ./ (d.^p + eps);

    % Gaussian distance kernel
    D("GaussianDistance") = @(d, sigma) ...
        exp(-d.^2 ./ (2*sigma.^2));

    % Compact support kernel
    D("CompactSupport") = @(d, R) ...
        max(0, 1 - d./R);

    %% =========================================================
    % OSCILLATORY / PERIODIC
    %% =========================================================

    % Sine wave
    D("Sine") = @(x, freq, phase) ...
        sin(2*pi*freq*x + phase);

    % Cosine wave
    D("Cosine") = @(x, freq, phase) ...
        cos(2*pi*freq*x + phase);

    % Complex exponential
    D("ComplexExp") = @(t, omega, phi0) ...
        exp(1i*(omega*t + phi0));

    %% =========================================================
    % PHASE / ANGULAR
    %% =========================================================

    % Wrap phase to [-π, π]
    D("WrapPhase") = @(phi) ...
        mod(phi + pi, 2*pi) - pi;

    % Phase difference
    D("PhaseDiff") = @(phi1, phi2) ...
        angle(exp(1i*(phi1 - phi2)));

    %% =========================================================
    % NORMALIZATION / SCALING
    %% =========================================================

    % Z-score normalization
    D("ZScore") = @(x) ...
        (x - mean(x)) ./ std(x);

    % Min-max scaling
    D("MinMax") = @(x) ...
        (x - min(x)) ./ (max(x) - min(x));

    % Unit norm (L2)
    D("UnitNorm") = @(x) ...
        x ./ vecnorm(x);

    %% =========================================================
    % PROBABILITY DENSITIES (unnormalized)
    %% =========================================================

    % Normal PDF
    D("NormalPDF") = @(x, mu, sigma) ...
        exp(-(x-mu).^2./(2*sigma.^2));

    % Log-normal PDF
    D("LogNormalPDF") = @(x, mu, sigma) ...
        (1./x) .* exp(-(log(x)-mu).^2./(2*sigma.^2));

    % Gamma PDF
    D("GammaPDF") = @(x, k, theta) ...
        x.^(k-1) .* exp(-x./theta);

    %% =========================================================
    % STOCHASTIC / NOISE
    %% =========================================================

    % White noise (Gaussian)
    D("WhiteNoise") = @(x) randn(size(x));

    % Uniform noise
    D("UniformNoise") = @(x) rand(size(x));

    % Pink noise (1/f-like)
    D("PinkNoise") = @(x) pinknoise(numel(x));

end

%% =========================================================
% LOCAL FUNCTIONS
%% =========================================================

function y = meyerFrequencyResponse(w)
%MEYERFREQUENCYRESPONSE  Meyer wavelet in frequency domain
%   Infinitely smooth transition function for ideal spectral filtering
    
    % Smooth transition auxiliary function
    nu = @(t) (t<=0).*0 + (t>=1).*1 + ...
              (t>0 & t<1).*(t.^4 .* (35 - 84*t + 70*t.^2 - 20*t.^3));
    
    % Meyer wavelet frequency response
    y = zeros(size(w));
    
    % Band 1: [2π/3, 4π/3]
    mask1 = abs(w)>=2*pi/3 & abs(w)<=4*pi/3;
    y(mask1) = exp(1i*w(mask1)/2) .* sin(pi/2 * nu(3*abs(w(mask1))/(2*pi) - 1));
    
    % Band 2: [4π/3, 8π/3]
    mask2 = abs(w)>=4*pi/3 & abs(w)<=8*pi/3;
    y(mask2) = exp(1i*w(mask2)/2) .* cos(pi/2 * nu(3*abs(w(mask2))/(4*pi) - 1));
end
