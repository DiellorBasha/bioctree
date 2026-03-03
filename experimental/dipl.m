% 3D field inspired by your 2D example, with real depth and better symmetry/stability
[x,y,z] = meshgrid(linspace(-3,3,45), linspace(-3,3,45), linspace(-3,3,45));

u = 2.*x.*y;
v = y.^2 - x.^2;

% Symmetric-in-y depth term (does NOT bias y>0 vs y<0)
w = 2.*y.*z;

% Normalize to keep streamlines from shooting out of the domain (purely for visualization)
mag = sqrt(u.^2 + v.^2 + w.^2) + 1e-6;
u = u ./ mag;  v = v ./ mag;  w = w ./ mag;

% FEWER seed points => fewer streamlines (control density here)
[sx,sy,sz] = meshgrid(linspace(-1.5,1.5,4), linspace(-1.5,1.5,4), linspace(-1.5,1.5,3));
% This makes 4*4*3 = 48 streamlines. Reduce more if you want.

% Streamline integration options: [stepSize, maxVertices]
opts = [0.6, 1000];

S = stream3(x,y,z,u,v,w,sx,sy,sz,opts);

figure('Color','w'); 
h = streamline(S); set(h,'LineWidth',0.6);
axis equal tight;  view(3);
xlabel('X'); ylabel('Y'); zlabel('Z');
title('3D Streamlines (stable, symmetric, lower density)');
camlight headlight; lighting gouraud;
ylim([-5 5])
xlim([-5 5])
zlim([-5 5])
figure('Color','w'); 

%%
% Illustration-grade EM dipole streamlines (symmetric)
p =1;                 % dipole strength (scale)
L = 15;                 % plot extent
n = 150;                % grid resolution

[x,y,z] = meshgrid(linspace(-L,L,n), linspace(-L,L,n), linspace(-L,L,n));

% Regularize near the origin to avoid blow-ups that chop streamlines
eps0 = 0.25;                          % increase if you still get chopped lines
r2 = x.^2 + y.^2 + z.^2 + eps0^2;
r  = sqrt(r2);

% Electric dipole E field (up to a constant), dipole moment along +z
pdotr = p * z;
Ex = 3 * x .* pdotr ./ (r.^5);
Ey = 3 * y .* pdotr ./ (r.^5);
Ez = 3 * z .* pdotr ./ (r.^5) - p ./ (r.^3);

% Optional: normalize magnitude for nicer, more uniform streamlines
mag = sqrt(Ex.^2 + Ey.^2 + Ez.^2) + 1e-9;
Ex = Ex ./ mag;  Ey = Ey ./ mag;  Ez = Ez ./ mag;

% Symmetric seeding: rings above AND below
t = linspace(0,2*pi,18);
r0 = 1.4;
sx = [r0*cos(t), r0*cos(t)];
sy = [r0*sin(t), r0*sin(t)];
sz = [ 1.8*ones(size(t)), -1.8*ones(size(t))];
t  = linspace(0,2*pi,40);

rList = [0.2 0.4 0.6];     % multiple ring radii
zList = [1.2 1.8 2.4];     % multiple heights (top), mirrored to bottom

sx = []; sy = []; sz = [];
for r0 = rList
    for z0 = zList
        sx = [sx, r0*cos(t), r0*cos(t)];
        sy = [sy, r0*sin(t), r0*sin(t)];
        sz = [sz, z0*ones(size(t)), -z0*ones(size(t))];
    end
end

% Streamlines
opts = [0.25, 500];   % [stepSize, maxVertices] => controls smoothness/length
S = stream3(x,y,z,Ex,Ey,Ez,sx,sy,sz,opts);
% Sphere seeding
nt = 24; np = 10;
theta = linspace(0,2*pi,nt);
phi   = linspace(0.3, pi-0.3, np);   % avoid poles
[TH,PH] = meshgrid(theta,phi);

rSeed = 1;
sx = rSeed .* sin(PH).*cos(TH);
sy = rSeed .* sin(PH).*sin(TH);
sz = rSeed .* cos(PH);

S = stream3(x,y,z,Ex,Ey,Ez,sx,sy,sz,opts);

clf
h = streamline(S); set(h,'LineWidth',0.25);
axis equal; grid off; view(3);
xlim([-L L]); ylim([-L L]); zlim([-L L]);
xlabel('X'); ylabel('Y'); zlabel('Z');

%%

%% Illustration-grade EM dipole streamlines (symmetric) with ring controls

%% Illustration-grade EM dipole streamlines (symmetric) — RING SEEDING ONLY

% -----------------------------
% Field / grid settings
% -----------------------------
p   = 1;        % dipole strength (scale)
L   = 15;       % plot extent
n   = 150;      % grid resolution

eps0 = 0.25;    % regularization near origin (increase if lines "chop")

% -----------------------------
% Streamline density controls (THIS controls # of streamlines)
% -----------------------------
nTheta   = 10;   % seed points per ring  (more => more streamlines)
Nrings   = 5;    % number of radii       (more => more streamlines)
NzLayers = 3;    % number of z layers    (more => more streamlines)

% Ring geometry (spacing/placement)
rMin = 0.8;      % smallest ring radius
dr   = 0.6;      % spacing between ring radii
zMin = 1.2;      % smallest |z| layer
dz   = 0.6;      % spacing between z layers

% -----------------------------
% Streamline integration controls
% -----------------------------
stepSize    = 0.25;   % smaller => smoother/longer (more compute)
maxVertices = 1500;   % larger  => longer lines
opts = [stepSize, maxVertices];

% ============================================================
% Build grid
% ============================================================
[x,y,z] = meshgrid(linspace(-L,L,n), linspace(-L,L,n), linspace(-L,L,n));

% ============================================================
% Dipole E-field (dipole moment along +z)
% ============================================================
r2 = x.^2 + y.^2 + z.^2 + eps0^2;
r  = sqrt(r2);

pdotr = p * z;
Ex = 3 * x .* pdotr ./ (r.^5);
Ey = 3 * y .* pdotr ./ (r.^5);
Ez = 3 * z .* pdotr ./ (r.^5) - p ./ (r.^3);

% Normalize magnitude for uniform-looking illustration (optional, but recommended)
mag = sqrt(Ex.^2 + Ey.^2 + Ez.^2) + 1e-9;
Ex = Ex ./ mag;  Ey = Ey ./ mag;  Ez = Ez ./ mag;

% ============================================================
% Ring seed points (symmetric: +z and -z)
% ============================================================
t = linspace(0, 2*pi, nTheta);

rList = rMin + dr*(0:Nrings-1);
zList = zMin + dz*(0:NzLayers-1);

sx = []; sy = []; sz = [];
for r0 = rList
    for z0 = zList
        % top ring (+z0) and mirrored bottom ring (-z0)
        sx = [sx, r0*cos(t), r0*cos(t)];
        sy = [sy, r0*sin(t), r0*sin(t)];
        sz = [sz, z0*ones(size(t)), -z0*ones(size(t))];
    end
end

% ============================================================
% Compute + plot streamlines
% ============================================================
S = stream3(x,y,z,Ex,Ey,Ez,sx,sy,sz,opts);

clf; hold on;
h = streamline(S);
set(h,'LineWidth',0.6);
axis equal off; view(3);
xlim([-L L]); ylim([-L L]); zlim([-L L]);
