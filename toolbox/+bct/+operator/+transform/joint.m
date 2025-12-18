function out = joint(in)
%BCT.OPERATOR.TRANSFORM.JOINT
%   Joint Manifold-Time Fourier Transform
%
%   Computes the joint transform over manifold and time dimensions:
%   1. Apply MFT (Manifold Fourier Transform) to spatial dimension
%   2. Apply FFT along time dimension
%
%   Mathematical representation:
%     x_hat_manifold = Phi' * M * x           [K x Nt]
%     x_hat_joint = fft(x_hat_manifold, [], 2) [K x Nt]
%
%   where:
%     x           - Signal on Manifold x Time [N x Nt]
%     x_hat_joint - Coefficients on Lambda x Omega [K x Nt]
%     Phi         - Eigenmodes [N x K]
%     M           - Mass matrix [N x N]
%
%   Input:
%     in  - bct.Signal on Joint(Manifold, Time) domain
%   Output:
%     out - bct.Signal on Joint(Lambda, Omega) domain
%
% Example:
%   % Create spatiotemporal signal
%   sig_st = bct.Signal(data, B.Manifold, B.Time);
%   
%   % Transform to spectral-frequency domain
%   sig_spectral = bct.operator.transform.joint(sig_st);
%   
%   % Access Lambda-Omega coefficients
%   coeff_joint = sig_spectral.Data;  % [K x Nt]
%
% See also: bct.operator.transform.mft, bct.operator.transform.ijoint

    arguments
        in (1,1) bct.Signal
    end

    % Validate input is on Joint domain
    if ~isa(in.Domain, 'bct.Joint')
        error("bct:operator:joint:InvalidDomain", ...
            "Input Signal must live on a Joint domain.");
    end
    
    % Validate first domain is Manifold
    manifold = in.Domain.A;
    if ~isa(manifold, 'bct.Manifold')
        error("bct:operator:joint:InvalidFirstDomain", ...
            "First component domain must be Manifold (got %s)", class(manifold));
    end
    
    % Validate second domain is Time
    time = in.Domain.B;
    if ~isa(time, 'bct.Time')
        error("bct:operator:joint:InvalidSecondDomain", ...
            "Second component domain must be Time (got %s)", class(time));
    end
    
    % Get dual domains
    lambda = manifold.dual;     % bct.Lambda
    omega = time.dual;          % bct.Omega
    
    if isempty(lambda) || isempty(omega)
        error("bct:operator:joint:NoDual", ...
            "Manifold and Time domains must have dual domains initialized.");
    end
    
    % Get transform components
    Phi = lambda.U;                      % [N x K] eigenmodes
    M = manifold.MassMatrix;             % [N x N] diagonal mass matrix
    
    % Step 1: Apply MFT to spatial dimension
    % x_hat_manifold = Phi' * M * x
    % x is [N x Nt], result is [K x Nt]
    coeff_manifold = Phi' * (M * in.Data);
    
    % Step 2: Apply FFT along time dimension (second dimension)
    % coeff_joint = fft(coeff_manifold, [], 2)
    coeff_joint = fft(coeff_manifold, [], 2);
    
    % Step 3: Apply fftshift to center zero frequency
    % Zero frequency is in the center, negative frequencies on left, positive on right
    coeff_joint = fftshift(coeff_joint, 2);
    
    % Create joint dual domain Lambda x Omega
    joint_dual = bct.Joint(lambda, omega);
    
    % Create metadata
    meta = struct();
    meta.Operator = 'joint';
    meta.ParentSignal = in.Id;
    meta.Transform = 'Manifold-Time to Lambda-Omega';
    
    out = bct.Signal(coeff_joint, joint_dual, [], meta);
end
