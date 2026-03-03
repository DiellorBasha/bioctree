addpath("toolbox\")
addpath("C:\CodingProjects\bioctree\external\bioelectromagnetism")
bct.start
fs4path='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial'
[vertices, faces] = freesurfer_read_surf(fs4path);
M=bct.Manifold(vertices,faces);
Mf=M.flip;clear M
M=Mf;
topo = M.topology;
geom = M.geometry;
ops=M.operators;
eigen=M.eigenmodes(1000);


bct.file.write.manifold('C:\CodingProjects\Bioctreeapp\src\app\data\bctfsaverage5.zarr', M);


% 2. Create time vector (10 sec, 100 Hz as you wanted)
fs = 100; T = 10;
t = (0:1/fs:T-1/fs)';

% 3. Generate test signal with known eigenmode/frequency content
components = [
    100,  10.0,  1.0;    % Eigenmode 100, 10 Hz
    300,  20.0,  0.7;    % Eigenmode 300, 20 Hz
    600,  15.0,  0.5;    % Eigenmode 600, 15 Hz
];
X = bct.spectral.generateTestSignal(M, components, t);


% Create Field (now using correct package name)
F = bct.field.make('support', 'vertex', 'valueType', 'scalar', ...
                   'value', X, 'time', struct('t0', 0, 'dt', 1/fs, 'unit', 's'));

% Compute spectrum
spec = bct.spectral.jointSpectrum(M, F);

% Visualize
bct.spectral.plotJointSpectrum(spec, 'Layout', 'full', 'MarkPeaks', true);

%%
G = bct.manifold.out(M, 'graph');
Nf = 6;
Wk = gsp_design_mexican_hat(G, Nf);
param_filter.filter = Wk;
Wkw = gsp_design_warped_translates(G,Nf,param_filter);
vertex_delta = 8251;
S = zeros(G.N*Nf,Nf);
S(vertex_delta) = 1;
for ii=1:Nf
    S(vertex_delta+(ii-1)*G.N,ii) = 1;
end

Sf = gsp_filter_synthesis(G,Wkw,S);
figure;
gsp_plot_filter(G,Wkw);


G.lmax=max(eigen.eigenvalues.value);
lambdas = linspace(0,G.lmax,1000);

% apply the filter
fd = gsp_filter_evaluate(Wkw,lambdas);
plot(lambdas,fd);
%%

viewer=bct.ui.show(M)
viewer.setScalar(Sf (:,1)+Sf (:,2)+Sf (:,3))

viewer.setScalar(Sf (:,6))

Sfz=zscore(Sf,0,2);
viewer.setScalar(Sfz(:,2))
Sfsum=sum(Sfz,2);
viewer.setScalar(Sfsum)

%%
tau = 1e-3;  % diffusion time step
A = ops.mass.value + tau*ops.stiffness.value;

% Factor once if you will step many times
R = chol(A, 'lower');  % works if SPD

step = @(u) R'\(R\(ops.mass.value*u));   % u_{new} = A^{-1} M u

u = rand(size(S,1),1);
u_new = step(u);

