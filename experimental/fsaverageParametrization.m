fsdir = "C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage6\surf";

% Left hemisphere
[V_pial,   F_pial]   = freesurfer_read_surf(fullfile(fsdir, "lh.pial"));
[V_sphere, F_sphere] = freesurfer_read_surf(fullfile(fsdir, "lh.sphere.reg")); % or lh.sphere

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
