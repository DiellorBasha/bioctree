function OUT = waveletDetectLineTime(X, x, t, varargin)
% waveletDetectLineTime  Multiscale wavelet analysis of a line-time array X(x,t).
% Detects wave energy at different spatial & temporal scales using undecimated 2D SWT.
%
% Inputs
%   X [Nx x T]  line-time data (rows=space, cols=time)
%   x [Nx x 1]  spatial coordinate
%   t [1  x T]  time vector
%
% Name-Value options (all optional)
%   'Wavelet'   : wavelet name for SWT (default 'db2')
%   'Levels'    : #levels (default: min(5, cap) with cap s.t. 2^J | Nx and 2^J | T)
%   'Boundary'  : 'per' or 'sym' (default 'per')
%   'MakePlots' : 0/1 (default 1)
%   'EnergyFn'  : 'L2' (squared) or 'L1' (abs) for energy maps (default 'L2')
%   'ThreshK'   : robust threshold multiplier (default 3.0)
%
% Output struct fields:
%   .H{j}/.V{j}/.D{j} (or 3D arrays)  detail coeffs per level
%   .E_H/.E_V/.E_D                    energy per level
%   .E_H_map/.E_V_map/.E_D_map        aggregated energy maps (same size as X)
%   .lambda_est/.period_est/.speed_est  rough scale->units per level
%   .mask_joint                       binary detection mask from joint (HH) energy
%   .params                           dx, dt, Fs, J, etc.

    % ---- parse options ----
    p = inputParser;
    addParameter(p,'Wavelet','db2');
    addParameter(p,'Levels',[]);
    addParameter(p,'Boundary','per');
    addParameter(p,'MakePlots',true);
    addParameter(p,'EnergyFn','L2');
    addParameter(p,'ThreshK',3.0);
    parse(p,varargin{:});
    opt = p.Results;

    % ---- grids & sampling ----
    [Nx,T] = size(X);
    x = x(:); t = t(:).';
    dx = median(diff(x));
    dt = median(diff(t));
    Fs = 1/dt; %#ok<NASU>

    % ---- choose safe SWT level (2^J must divide Nx and T) ----
    capNx = pow2factor(Nx);
    capT  = pow2factor(T);
    Jcap  = min(capNx, capT);
    if Jcap == 0
        error('SWT requires both dimensions even. Got size(X) = [%d %d].', Nx, T);
    end
    if isempty(opt.Levels)
        J = max(1, min(5, Jcap));
    else
        J = min(opt.Levels, Jcap);
        if opt.Levels > Jcap
            warning('Requested Levels=%d but cap is %d (2^J must divide both dims). Using J=%d.', ...
                    opt.Levels, Jcap, J);
        end
    end

    % ---- SWT (undecimated) ----
    dwtmode(opt.Boundary,'nodisp');
    [~, H, V, D] = swt2(X, J, opt.Wavelet);

    % unify per-level access (cell vs 3D array, depends on MATLAB release)
    if iscell(H)
        getLevel = @(C,j) C{j};
    else
        getLevel = @(C,j) C(:,:,j);
    end

    % ---- energy maps ----
    useL2 = strcmpi(opt.EnergyFn,'L2');
    E_H = zeros(1,J); E_V = E_H; E_D = E_H;
    E_H_map = zeros(Nx,T); E_V_map = E_H_map; E_D_map = E_H_map;

    for j = 1:J
        Hj = getLevel(H,j);
        Vj = getLevel(V,j);
        Dj = getLevel(D,j);

        if useL2
            HjE = Hj.^2; VjE = Vj.^2; DjE = Dj.^2;
        else
            HjE = abs(Hj); VjE = abs(Vj); DjE = abs(Dj);
        end
        E_H(j) = sum(HjE(:));
        E_V(j) = sum(VjE(:));
        E_D(j) = sum(DjE(:));
        E_H_map = E_H_map + HjE;
        E_V_map = E_V_map + VjE;
        E_D_map = E_D_map + DjE;
    end

    % ---- rough scale→units mapping (dyadic heuristic) ----
    jvec = 1:J;
    period_est = 2.^(jvec+1) * dt;     % seconds
    lambda_est = 2.^(jvec+1) * dx;     % space units
    speed_est  = lambda_est ./ period_est;

    % ---- joint-activity mask (robust threshold) ----
    medD = median(E_D_map(:));
    madD = median(abs(E_D_map(:) - medD)) + eps;
    thr  = medD + opt.ThreshK * 1.4826 * madD;
    mask_joint = E_D_map > thr;

    % ---- pack outputs ----
    OUT = struct;
    OUT.H = H; OUT.V = V; OUT.D = D;
    OUT.E_H = E_H; OUT.E_V = E_V; OUT.E_D = E_D;
    OUT.E_H_map = E_H_map; OUT.E_V_map = E_V_map; OUT.E_D_map = E_D_map;
    OUT.lambda_est = lambda_est;
    OUT.period_est = period_est;
    OUT.speed_est  = speed_est;
    OUT.mask_joint = mask_joint;
    OUT.params = struct('dx',dx,'dt',dt,'Fs',Fs,'J',J,'Wavelet',opt.Wavelet,'Boundary',opt.Boundary,...
                        'EnergyFn',opt.EnergyFn,'ThreshK',opt.ThreshK);

    % ---- quick plots ----
    if opt.MakePlots
        figure('Color','w','Name','Line-Time SWT analysis');
        tl = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

        ax1 = nexttile(tl,1);
        imagesc(ax1, t, x, X); axis(ax1,'xy'); colorbar(ax1);
        xlabel(ax1,'Time'); ylabel(ax1,'x'); title(ax1,'X (line-time)');

        ax2 = nexttile(tl,2);
        imagesc(ax2, t, x, OUT.E_D_map); axis(ax2,'xy'); colorbar(ax2);
        xlabel(ax2,'Time'); ylabel(ax2,'x'); title(ax2,'Joint (HH) energy (sum over levels)');

        ax3 = nexttile(tl,3);
        imagesc(ax3, t, x, OUT.mask_joint); axis(ax3,'xy'); colorbar(ax3);
        xlabel(ax3,'Time'); ylabel(ax3,'x'); title(ax3,'Joint activity mask');

        ax4 = nexttile(tl,4);
        plot(ax4, jvec, OUT.E_H, '-o', jvec, OUT.E_V, '-s', jvec, OUT.E_D, '-^','LineWidth',1.5);
        grid(ax4,'on'); xlabel(ax4,'Level j'); ylabel(ax4,'Energy');
        legend(ax4,'Temporal (H)','Spatial (V)','Joint (D)','Location','best');
        title(ax4,'Band energies across scales');
    end
end

function e = pow2factor(n)
% number of times 2 divides n (2-adic valuation), for n>0 integer
    e = 0;
    while mod(n,2)==0
        n = n/2; e = e+1;
    end
end
