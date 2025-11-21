classdef Transform
    %TRANSFORM  Enumeration of transform types in the BCT system.
    %
    % These represent the canonical transforms between dual domains:
    %   FFT   - Time → Omega
    %   IFFT  - Omega → Time
    %   GFT   - Space → Lambda  (graph Laplacian eigenbasis)
    %   IGFT  - Lambda → Space
    %   JOINT - Joint transform (Space×Time, Lambda×Omega)

    enumeration
        FFT        % Forward Fourier transform (time → frequency)
        IFFT       % Inverse Fourier transform (frequency → time)
        GFT        % Forward graph/manifold Fourier transform
        IGFT       % Inverse graph/manifold Fourier transform
        JOINT      % Separable joint transform
    end
end
