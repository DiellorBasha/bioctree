function out = ijoint(in)
%BCT.OPERATOR.TRANSFORM.IJOINT
%   Inverse Joint Manifold-Time Fourier Transform
%
%   Computes the inverse joint transform from Lambda-Omega to Manifold-Time:
%   1. Apply IFFT along frequency dimension
%   2. Apply IMFT (Inverse Manifold Fourier Transform) to spectral dimension
%
%   Mathematical representation:
%     x_hat_manifold = ifft(x_hat_joint, [], 2)  [K x Nt]
%     x_rec = Phi * x_hat_manifold                 [N x Nt]
%
%   where:
%     x_hat_joint - Coefficients on Lambda x Omega [K x Nt]
%     x_rec       - Signal on Manifold x Time [N x Nt]
%     Phi         - Eigenmodes [N x K]
%
%   Input:
%     in  - bct.Signal on Joint(Lambda, Omega) domain
%   Output:
%     out - bct.Signal on Joint(Manifold, Time) domain
%
% Example:
%   % Transform from spectral-frequency to spatiotemporal
%   sig_st = bct.operator.transform.ijoint(sig_spectral);
%   
%   % Access spatiotemporal data
%   data_st = sig_st.Data;  % [N x Nt]
%
% See also: bct.operator.transform.joint, bct.operator.transform.imft

    arguments
        in (1,1) bct.Signal
    end

    % Validate input is on Joint domain
    if ~isa(in.Domain, 'bct.Joint')
        error("bct:operator:ijoint:InvalidDomain", ...
            "Input Signal must live on a Joint domain.");
    end
    
    % Validate first domain is Lambda
    lambda = in.Domain.A;
    if ~isa(lambda, 'bct.Lambda')
        error("bct:operator:ijoint:InvalidFirstDomain", ...
            "First component domain must be Lambda (got %s)", class(lambda));
    end
    
    % Validate second domain is Omega
    omega = in.Domain.B;
    if ~isa(omega, 'bct.Omega')
        error("bct:operator:ijoint:InvalidSecondDomain", ...
            "Second component domain must be Omega (got %s)", class(omega));
    end
    
    % Get dual domains
    manifold = lambda.dual;     % bct.Manifold
    time = omega.dual;          % bct.Time
    
    if isempty(manifold) || isempty(time)
        error("bct:operator:ijoint:NoDual", ...
            "Lambda and Omega domains must have dual domains initialized.");
    end
    
    % Get eigenmodes
    Phi = lambda.U;             % [N x K] eigenmodes
    
    % Step 1: Undo fftshift from forward transform
    coeff_joint_shifted = ifftshift(in.Data, 2);
    
    % Step 2: Apply IFFT along frequency dimension (second dimension)
    % x_hat_manifold = ifft(x_hat_joint, [], 2)
    coeff_manifold = ifft(coeff_joint_shifted, [], 2);
    
    % Step 3: Apply IMFT to spectral dimension
    % x_rec = Phi * x_hat_manifold
    % coeff_manifold is [K x Nt], result is [N x Nt]
    data_st = Phi * coeff_manifold;
    
    % Create joint domain Manifold x Time
    joint_spatial = bct.Joint(manifold, time);
    
    % Create metadata
    meta = struct();
    meta.Operator = 'ijoint';
    meta.ParentSignal = in.Id;
    meta.Transform = 'Lambda-Omega to Manifold-Time';
    
    out = bct.Signal(data_st, joint_spatial, [], meta);
end
