function meshes = fem_heat_smooth(G, taus, varargin)
% FEM implicit heat smoothing of vertex coordinates.
% X(t) = (M + t L) \ (M * X0), faces unchanged.
%
% Usage:
%   meshes = fem_heat_smooth(G, taus);                          % defaults
%   meshes = fem_heat_smooth(G, taus, 'solver','chol');         % name–value
%   meshes = fem_heat_smooth(G, taus, 'solver','pcg','tol',1e-8,'maxit',500);

% ---- parse name–value args ----
p = inputParser;
p.FunctionName = 'fem_heat_smooth';
addParameter(p,'solver','chol');      % 'chol' or 'pcg'
addParameter(p,'tol',1e-8);
addParameter(p,'maxit',500);
addParameter(p,'recenter',false);
parse(p, varargin{:});
solver   = validatestring(p.Results.solver, {'chol','pcg'});
tol      = p.Results.tol;
maxit    = p.Results.maxit;
recenter = p.Results.recenter;

% ---- grab data ----
V0 = double(G.coords);     % N×3
L  = G.L;                  % sparse (cotan stiffness)
M  = G.M;                  % sparse (lumped mass)
F  = G.Faces;
N  = size(V0,1);

meshes = cell(numel(taus),1);
ctr0 = mean(V0,1);         % for optional recentering

for k = 1:numel(taus)
    t = taus(k);
    A = M + t*L;                               % SPD

    switch solver
        case 'chol'
            % sparse Cholesky with fill-reducing ordering
            pperm = amd(A);
            R = chol(A(pperm,pperm));          % A(p,p) = R'*R
            B = M * V0;                        % N×3
            Y = zeros(N,3);
            Y(pperm,:) = R \ (R' \ B(pperm,:));
            Xt = Y;

        case 'pcg'
            % PCG (memory-friendlier for huge meshes)
            setup.type = 'ict'; setup.droptol = 1e-3;
            try
                P = ichol(A, setup);
            catch
                P = [];  % fallback
            end
            B = M * V0;
            Xt = zeros(N,3);
            for j = 1:3
                if ~isempty(P)
                    [Xt(:,j), flag] = pcg(A, B(:,j), tol, maxit, P, P');
                else
                    [Xt(:,j), flag] = pcg(A, B(:,j), tol, maxit);
                end
                if flag ~= 0
                    warning('PCG did not fully converge for coord %d at tau=%g (flag=%d).', j, t, flag);
                end
            end
    end

    if recenter
        ctr = mean(Xt,1);
        Xt = bsxfun(@minus, Xt, ctr) + ctr0;
    end

    Gi = surfaceMesh(Xt, F);
    computeNormals(Gi);
    meshes{k} = Gi;
end
end
