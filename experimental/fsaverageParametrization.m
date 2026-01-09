fsdir = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage\surf";

% Left hemisphere
[V_pial,   F_pial]   = freesurfer_read_surf(fullfile(fsdir, "lh.pial"));
[V_sphere, F_sphere] = freesurfer_read_surf(fullfile(fsdir, "lh.sphere.reg")); % or lh.sphere

savePath='C:\CodingProjects\bioctree\toolbox\+bct\+data\assets\fsaverage6\surf\fsaverage6_hemi-lh_sphere.mat'


% Sanity checks
if ~isequal(F_pial, F_sphere)
    warning("Faces differ between pial and sphere; using pial faces for everything.");
end

% If faces are 0-based for any reader, fix it once:
if min(F_pial(:)) == 0
    F_pial = F_pial + 1;
end

%% Convert sphere coordinates to UV

% Ensure sphere is roughly centered; fs spheres usually are, but be safe:
Vs = V_sphere - mean(V_sphere, 1);

% Spherical angles
[az, el, r] = cart2sph(Vs(:,1), Vs(:,2), Vs(:,3));  % az in [-pi, pi], el in [-pi/2, pi/2]

% UV in [0,1]x[0,1] (equirectangular parameterization)
U = (az + pi) / (2*pi);
V = (el + pi/2) / pi;

UV = [U V];   % Nx2

%%
mesh = struct();
mesh.Vertices = V_pial;
mesh.Faces    = F_pial;
mesh.SphereVertices = V_sphere;   % keep the 3D sphere too (useful for spherical ops)
mesh.UV = UV;                     % 2D parameterization
%%
trisurf(F_pial, V_pial(:,1), V_pial(:,2), V_pial(:,3), UV(:,1), ...
    'EdgeColor','none'); axis equal; camlight; lighting gouraud;
title('Pial surface colored by U');

figure;
scatter(UV(:,1), UV(:,2), 2, '.', 'MarkerEdgeAlpha', 0.2);
axis equal tight; title('UV scatter (seam at U=0/1)');

%%
fsdir = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage6\surf";

[Vp, Fp] = freesurfer_read_surf(fullfile(fsdir, "lh.pial"));
[Vi, Fi] = freesurfer_read_surf(fullfile(fsdir, "lh.inflated"));

% Ensure 1-based faces if needed
if min(Fp(:)) == 0, Fp = Fp + 1; end
if min(Fi(:)) == 0, Fi = Fi + 1; end

% Topology sanity check (recommended)
if ~isequal(Fp, Fi)
    warning("Faces differ between pial and inflated; using pial faces for display.");
end

% UI
fig = uifigure('Position',[100 100 1200 800], 'Color','k');
gl  = uigridlayout(fig,[2 1]);
gl.RowHeight = {'1x', 60};

ax = uiaxes(gl);
ax.Color = 'k';
axis(ax,'equal'); axis(ax,'off'); axis(ax,'vis3d');
view(ax, 3);

% Patch (create once; update vertices only)
p = patch(ax, 'Faces', Fp, 'Vertices', Vp, ...
    'FaceColor',[0.85 0.85 0.85], 'EdgeColor','none', ...
    'SpecularStrength',0.2, 'DiffuseStrength',0.8, 'AmbientStrength',0.25);
camlight(ax,'headlight'); lighting(ax,'gouraud');

% Slider
s = uislider(gl, 'Limits',[0 1], 'Value',0, ...
    'MajorTicks',0:0.25:1, 'MinorTicks',[]);
s.ValueChangingFcn = @(src,evt) updateMesh(evt.Value);
s.ValueChangedFcn  = @(src,evt) updateMesh(evt.Value);

    function updateMesh(t)
        % Optional easing (feels nicer than linear):
        % t = t*t*(3 - 2*t);  % smoothstep
        Vt = (1-t).*Vp + t.*Vi;
        p.Vertices = Vt;

        % If you rely heavily on lighting cues, you may want to refresh normals.
        % Usually fine without it, but if needed:
        % p.VertexNormals = []; % let MATLAB recompute lazily
        drawnow limitrate;
    end

%%
fsdir = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage\surf";

[V_sphere, F_sphere] = freesurfer_read_surf(fullfile(fsdir, "lh.sphere.reg")); % or "lh.sphere"

% Ensure 1-based faces (some readers return 0-based)
if min(F_sphere(:)) == 0
    F_sphere = F_sphere + 1;
end

% Match desired types
V = double(V_sphere);
F = int32(F_sphere);

savePath = 'C:\CodingProjects\bioctree\toolbox\+bct\+data\assets\fsaverage6\surf\fsaverage6_hemi-lh_sphere.mat';

% Save as a MAT-file with variables V and F (will load as fields a.V and a.F)
save(savePath, 'V', 'F', '-v7.3');

%% Convert sphere coordinates to UV

% Inputs: V_sphere, F_sphere from freesurfer_read_surf
if min(F_sphere(:)) == 0
    F_sphere = F_sphere + 1;
end

V = double(V_sphere);
F = int32(F_sphere);

% ---- UV parameterization from spherical embedding (equirectangular) ----
Vs = V - mean(V, 1);  % center used for angles

[az, el, ~] = cart2sph(Vs(:,1), Vs(:,2), Vs(:,3));  % radians
U = (az + pi) / (2*pi);
Vv = (el + pi/2) / pi;

UV = [U, Vv];  % [Nv×2], in [0,1]

UVInfo = struct();
UVInfo.Method        = "sphere_equirectangular";
UVInfo.Centering     = "subtract_mean";
UVInfo.AngleUnits    = "radians";
UVInfo.U_Range       = [0 1];
UVInfo.V_Range       = [0 1];
UVInfo.Seam          = "U wraps at 0/1 (azimuth -pi/pi)";
UVInfo.Poles         = "V=0/1 correspond to south/north poles";
UVInfo.SourceSurface = "lh.sphere.reg"; % or "lh.sphere"

savePath = 'C:\CodingProjects\bioctree\toolbox\+bct\+data\assets\fsaverage6\surf\fsaverage6_hemi-lh_sphere.mat';
save(savePath, 'V', 'F', 'UV', 'UVInfo', '-v7.3');

%%
fsdir = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage\surf";

[V_sphere, F_sphere] = freesurfer_read_surf(fullfile(fsdir, "rh.sphere.reg")); % or "lh.sphere"

% Ensure 1-based faces (some readers return 0-based)
if min(F_sphere(:)) == 0
    F_sphere = F_sphere + 1;
end

% Match desired types
V = double(V_sphere);
F = int32(F_sphere);

savePath = 'C:\CodingProjects\bioctree\toolbox\+bct\+data\assets\fsaverage6\surf\fsaverage6_hemi-rh_sphere.mat';

% Save as a MAT-file with variables V and F (will load as fields a.V and a.F)
save(savePath, 'V', 'F', '-v7.3');

%% Convert sphere coordinates to UV

% Inputs: V_sphere, F_sphere from freesurfer_read_surf
if min(F_sphere(:)) == 0
    F_sphere = F_sphere + 1;
end

V = double(V_sphere);
F = int32(F_sphere);

% ---- UV parameterization from spherical embedding (equirectangular) ----
Vs = V - mean(V, 1);  % center used for angles

[az, el, ~] = cart2sph(Vs(:,1), Vs(:,2), Vs(:,3));  % radians
U = (az + pi) / (2*pi);
Vv = (el + pi/2) / pi;

UV = [U, Vv];  % [Nv×2], in [0,1]

UVInfo = struct();
UVInfo.Method        = "sphere_equirectangular";
UVInfo.Centering     = "subtract_mean";
UVInfo.AngleUnits    = "radians";
UVInfo.U_Range       = [0 1];
UVInfo.V_Range       = [0 1];
UVInfo.Seam          = "U wraps at 0/1 (azimuth -pi/pi)";
UVInfo.Poles         = "V=0/1 correspond to south/north poles";
UVInfo.SourceSurface = "lh.sphere.reg"; % or "lh.sphere"

savePath = 'C:\CodingProjects\bioctree\toolbox\+bct\+data\assets\fsaverage6\surf\fsaverage6_hemi-rh_sphere.mat';
save(savePath, 'V', 'F', 'UV', 'UVInfo', '-v7.3');
%%
% Paths
fsdir = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage6\surf";

% ---------- Left hemisphere: lh.inflated ----------
[V_lh, F_lh] = freesurfer_read_surf(fullfile(fsdir, "lh.inflated"));

% Ensure 1-based faces (some readers return 0-based)
if min(F_lh(:)) == 0
    F_lh = F_lh + 1;
end

% Match your desired MAT schema/types
V = double(V_lh);
F = int32(F_lh);

savePath = 'C:\CodingProjects\bioctree\toolbox\+bct\+data\assets\fsaverage6\surf\fsaverage6_hemi-lh_inflated.mat';
save(savePath, 'V', 'F', '-v7.3');


% ---------- Right hemisphere: rh.inflated ----------
[V_rh, F_rh] = freesurfer_read_surf(fullfile(fsdir, "rh.inflated"));

% Ensure 1-based faces
if min(F_rh(:)) == 0
    F_rh = F_rh + 1;
end

V = double(V_rh);
F = int32(F_rh);

savePath = 'C:\CodingProjects\bioctree\toolbox\+bct\+data\assets\fsaverage6\surf\fsaverage6_hemi-rh_inflated.mat';
save(savePath, 'V', 'F', '-v7.3');


%% Geometry export
V=M.Vertices; F=M.Faces; 
UV=load('C:\CodingProjects\bioctree\toolbox\+bct\+data\assets\fsaverage6\surf\fsaverage6_hemi-lh_sphere.mat');
savePathJSON='C:\CodingProjects\bioctree-ui-library\+bct\+ui\+manifold\+viewer\web\assets\fsaverage.json'

vertices = single(V');      % 3 x N
vertices = vertices(:)';    % 1 x (3N)

faces = int32(F' - 1);      % 3 x M, 0-based
faces = faces(:)';          % 1 x (3M)

uv = single(UV');           % 2 x N
uv = uv(:)';                % 1 x (2N)

vertices = single(V');      % 3 x N
vertices = vertices(:)';    % 1 x (3N)

faces = int32(F' - 1);      % 3 x M, 0-based
faces = faces(:)';          % 1 x (3M)

uv = single(UV');           % 2 x N
uv = uv(:)';                % 1 x (2N)

jsonText = jsonencode(meshJSON);
jsonText = prettyjson(jsonText);   % optional but recommended

fid = fopen(savePathJSON, 'w');
fwrite(fid, jsonText, 'char');
fclose(fid);

