function K = telegraph(manifold, varargin)
%TELEGRAPH Telegraph equation (damped wave) propagator K(λ,t)
%
%   K = telegraph(manifold) creates telegraph equation propagator
%   K = telegraph(manifold, 'c', c, 'gamma', g) sets parameters
%
%   The telegraph equation combines wave propagation with damping:
%       ∂²u/∂t² + 2γ∂u/∂t + c²Δu = 0
%
%   Spectral propagator:
%       K(λ, t) = exp(-γt) * [cos(ω_λ*t) + (γ/ω_λ)*sin(ω_λ*t)]
%   where:
%       ω_λ = sqrt(c²λ - γ²) for underdamped (c²λ > γ²)
%       ω_λ = i*sqrt(γ² - c²λ) for overdamped (c²λ < γ²)
%
%   Inputs:
%     manifold - bct.manifold.Manifold object
%     'c'      - Wave speed (default: 1)
%     'gamma'  - Damping coefficient (default: 0.1)
%
%   Returns:
%     K - Function handle @(lambda, t) for telegraph propagator
%
%   Example:
%       % Damped wave on manifold
%       K = bct.filters.design.joint.dynamic.telegraph(B.Manifold, ...
%                                                       'c', 1, 'gamma', 0.2);
%
%   See also: bct.filters.design.joint.dynamic.wave,
%             bct.filters.design.joint.dynamic.heat

% Parse inputs
p = inputParser;
addRequired(p, 'manifold');
addParameter(p, 'c', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'gamma', 0.1, @(x) isnumeric(x) && x >= 0);
parse(p, manifold, varargin{:});

c = p.Results.c;
gamma = p.Results.gamma;

% Telegraph propagator with damping
K = @(lambda, t) telegraph_kernel(lambda, t, c, gamma);

end

function y = telegraph_kernel(lambda, t, c, gamma)
%TELEGRAPH_KERNEL Evaluate telegraph equation propagator
    % Discriminant: c²λ - γ²
    discriminant = c^2 * lambda - gamma^2;
    
    % Exponential decay
    decay = exp(-gamma * t);
    
    % Underdamped case: c²λ > γ² (oscillatory)
    underdamped = discriminant > 0;
    omega = sqrt(abs(discriminant));
    
    y = zeros(size(lambda));
    
    if any(underdamped(:))
        omega_ud = omega(underdamped);
        t_mat = t;
        if isscalar(t)
            t_mat = t * ones(size(lambda));
        end
        t_ud = t_mat(underdamped);
        
        y(underdamped) = decay * (cos(omega_ud .* t_ud) + ...
                                  (gamma ./ omega_ud) .* sin(omega_ud .* t_ud));
    end
    
    % Overdamped case: c²λ < γ² (exponential decay)
    overdamped = discriminant < 0;
    if any(overdamped(:))
        omega_od = omega(overdamped);
        t_mat = t;
        if isscalar(t)
            t_mat = t * ones(size(lambda));
        end
        t_od = t_mat(overdamped);
        
        y(overdamped) = decay * (cosh(omega_od .* t_od) + ...
                                 (gamma ./ omega_od) .* sinh(omega_od .* t_od));
    end
    
    % Critical damping: c²λ = γ²
    critical = abs(discriminant) < eps;
    if any(critical(:))
        t_mat = t;
        if isscalar(t)
            t_mat = t * ones(size(lambda));
        end
        t_cr = t_mat(critical);
        
        y(critical) = decay * (1 + gamma * t_cr);
    end
end
