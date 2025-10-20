function [Y, ty] = crossfadeXT(X, t, X1, t1, overlapSec)
% Crossfade two line-wave clips X(x,t) and X1(x,t1) over overlapSec seconds.
% Assumes same x-grid and (approximately) same dt for t and t1.

    % ---- checks ----
    [Nx,T0] = size(X); [Nx1,T1] = size(X1);
    assert(Nx==Nx1, 'Spatial size (Nx) must match.');
    dt  = median(diff(t));  dt1 = median(diff(t1));
    assert(abs(dt-dt1) < 1e-6*max(dt,dt1), 't and t1 must have same sampling.');
    K = max(1, min([T0, T1, round(overlapSec/dt)]));

    % ---- half-cosine crossfade weights w: 0->1 (length K) ----
    u = linspace(0,1,K);
    w = 0.5*(1 - cos(pi*u));              % row 1×K
    % tails/heads
    X_tail  = X(:, end-K+1:end);
    X1_head = X1(:, 1:K);
    % blend (implicit expansion)
    X_blend = X_tail .* (1 - w) + X1_head .* w;

    % ---- stitch ----
    Y  = [ X(:, 1:end-K),  X_blend,  X1(:, K+1:end) ];
    ty = [ t(1:end-K),     t(end-K+1:end),          t1(K+1:end) ];
end
