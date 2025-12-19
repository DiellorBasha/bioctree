function G = generators()
%BCT.KERNEL.GENERATORS  Basis generator function registry
%
%   G = bct.kernel.generators()
%
% Returns a dictionary mapping generator names to factory functions.
% These are NOT pure analytic kernels - they are operator-defined
% or discrete basis functions that require parameter-specific construction.
%
% Key distinction from bct.kernel.dictionary():
%   - dictionary() → closed-form analytic functions
%   - generators() → factory functions for discrete/operator-defined bases
%
% Usage:
%   G = bct.kernel.generators();
%   
%   % Get Daubechies wavelet coefficients
%   dbFactory = G("Daubechies");
%   [phi,psi,xval] = dbFactory(4);  % db4 wavelet
%   
%   % Get Slepian sequences (DPSS)
%   slepianFactory = G("Slepian");
%   [v, lambda] = slepianFactory(1024, 4);  % N=1024, NW=4
%   
%   % List available generators
%   generatorNames = keys(G);
%
% Conceptual Note:
%   The most balanced functions are eigenfunctions of symmetry-defining
%   operators. Analytic kernels (dictionary) approximate this balance;
%   Slepian and Hermite achieve it optimally.
%
% See also: bct.kernel.dictionary, bct.kernel.registry, bct.kernel.get

    G = dictionary();

    %% =========================================================
    % DISCRETE WAVELET BASIS GENERATORS
    %% =========================================================

    % Daubechies wavelets (no closed form)
    % Defined by filter coefficients and refinement equations
    % N = number of vanishing moments (1-45)
    % Returns: [phi, psi, xval] = scaling function, wavelet, support
    G("Daubechies") = @(N) wavefun(sprintf('db%d', N), 10);

    % Symlets (symmetric Daubechies)
    G("Symlet") = @(N) wavefun(sprintf('sym%d', N), 10);

    % Coiflets (more symmetric)
    G("Coiflet") = @(N) wavefun(sprintf('coif%d', N), 10);

    % Biorthogonal wavelets
    % Returns: [psi1, psi2, xval1, xval2]
    G("Biorthogonal") = @(Nr, Nd) ...
        wavefun(sprintf('bior%d.%d', Nr, Nd), 10);

    %% =========================================================
    % OPTIMAL CONCENTRATION BASIS
    %% =========================================================

    % Slepian / Prolate Spheroidal Wave Functions (DPSS)
    % Eigenfunctions of band-limited Laplacian on finite domain
    % Ordered by concentration ratio
    % N = sequence length
    % NW = time-bandwidth product (typically 2.5-4)
    % Returns: [v, lambda] = sequences, eigenvalues
    G("Slepian") = @(N, NW) dpss(N, NW);

    % Slepian with specified number of sequences
    G("SlepianK") = @(N, NW, K) dpss(N, NW, K);

    %% =========================================================
    % SPECTRAL FILTER BANK GENERATORS
    %% =========================================================

    % Meyer wavelet (time-domain via inverse FFT)
    % Returns actual wavelet function, not frequency response
    G("MeyerTime") = @(iterations) wavefun('meyr', iterations);

    % Haar wavelet (simplest, discontinuous)
    G("Haar") = @() wavefun('haar', 10);

    %% =========================================================
    % MULTITAPER GENERATORS
    %% =========================================================

    % DPSS for multitaper spectral estimation
    % Returns tapers and concentration ratios
    G("Multitaper") = @(N, NW, K) dpss(N, NW, 'trace');

end
