%% ============================================================
%  Diagnostics: do different (tau, nStep) produce different u_heat?
%  Assumes you already have: stiffness, mass, delta (seeded), nV
%  ============================================================

% Helper: one implicit Euler heat step operator for a given tau
heatSolve = @(tau, nStep, u0) localHeatRun(mass, stiffness, tau, nStep, u0);

% Choose a grid of test settings (include "small time" and "large time" cases)
tauList   = [1e-6 1e-5 1e-4 1e-3 1e-2 1e-1 1];
nStepList = [1 2 5 10 50];

% Run all cases and store results
cases = [];
U = {};   % cell array of solutions

idx = 0;
for i = 1:numel(tauList)
    for j = 1:numel(nStepList)
        idx = idx + 1;
        tau   = tauList(i);
        nStep = nStepList(j);
        u_heat = heatSolve(tau, nStep, delta);

        U{idx} = u_heat;
        cases(idx).tau   = tau; %#ok<SAGROW>
        cases(idx).nStep = nStep;
        cases(idx).T     = tau*nStep;  % total diffusion time

        % Basic stats that SHOULD change as diffusion changes
        cases(idx).maxv  = max(u_heat);
        cases(idx).minv  = min(u_heat);
        cases(idx).stdv  = std(u_heat);

        % Mass-weighted mean (steady state on closed surface)
        one = ones(size(u_heat));
        meanM = (one'*(mass*u_heat)) / (one'*(mass*one));
        cases(idx).meanM = meanM;
        cases(idx).stdOverMean = cases(idx).stdv / max(abs(meanM), eps);
    end
end

% Print a compact table of results
fprintf('\n%-10s %-6s %-10s %-12s %-12s %-12s %-12s %-12s\n', ...
    'tau','nStep','T','max','min','std','mean_M','std/mean');
for c = 1:numel(cases)
    fprintf('%-10.1e %-6d %-10.1e %-12.3e %-12.3e %-12.3e %-12.3e %-12.3e\n', ...
        cases(c).tau, cases(c).nStep, cases(c).T, ...
        cases(c).maxv, cases(c).minv, cases(c).stdv, cases(c).meanM, cases(c).stdOverMean);
end

% Pairwise differences: pick a reference (small diffusion) and compare
refIdx = 1;  % first case (tauList(1), nStepList(1))
u_ref  = U{refIdx};

fprintf('\nReference: tau=%.1e, nStep=%d, T=%.1e\n', ...
    cases(refIdx).tau, cases(refIdx).nStep, cases(refIdx).T);
fprintf('%-10s %-6s %-10s %-14s %-14s\n', 'tau','nStep','T','||u-u_ref||2','rel');

for c = 1:numel(cases)
    du = U{c} - u_ref;
    absNorm = norm(du,2);
    relNorm = absNorm / max(norm(u_ref,2), eps);
    fprintf('%-10.1e %-6d %-10.1e %-14.3e %-14.3e\n', ...
        cases(c).tau, cases(c).nStep, cases(c).T, absNorm, relNorm);
end

% Optional: visualize a few representative cases as residuals to steady state
% (helps avoid "everything looks the same" due to auto color scaling / equilibration)
showIdx = unique([1, findClosestCase(cases, 1e-4, 10), findClosestCase(cases, 1e-2, 10), findClosestCase(cases, 1e-1, 10), numel(cases)]);
fprintf('\nVisual check indices: %s\n', mat2str(showIdx));

% If you have a viewer object:
% for c = showIdx
%     u = U{c};
%     one = ones(size(u));
%     meanM = (one'*(mass*u)) / (one'*(mass*one));
%     viewer.setScalar(u - meanM);  % residual
%     titleStr = sprintf('tau=%.1e, nStep=%d, T=%.1e', cases(c).tau, cases(c).nStep, cases(c).T);
%     disp(titleStr);
%     pause;
% end


%% ----------------- local helper functions -----------------
function u_out = localHeatRun(mass, stiffness, tau, nStep, u0)
    % Build implicit heat operator: (M + tau*S)
    A_heat = mass + tau * stiffness;
    A_heat = (A_heat + A_heat')/2;  % enforce symmetry

    % Cholesky factorization (SPD for tau>0)
    R = chol(A_heat, 'lower');

    u = u0;
    for k = 1:nStep
        rhs = mass * u;
        u   = R' \ (R \ rhs);
    end
    u_out = u;
end

function idx = findClosestCase(cases, tauTarget, nStepTarget)
    taus   = [cases.tau];
    nSteps = [cases.nStep];
    score = abs(log10(taus) - log10(tauTarget)) + 0.2*abs(nSteps - nStepTarget);
    [~, idx] = min(score);
end
