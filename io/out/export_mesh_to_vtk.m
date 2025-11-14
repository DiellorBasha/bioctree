function export_mesh_to_vtk(filename, V, F, varargin)
% export_mesh_to_vtk - Export triangle mesh with data to legacy VTK POLYDATA format
%
% This function writes a triangular mesh to a VTK (Visualization Toolkit)
% ASCII file in the legacy POLYDATA format, which can be visualized in
% ParaView, VisIt, MayaVi, or other VTK-compatible viewers. The function
% supports exporting both geometric mesh data and associated scalar/vector
% fields defined at vertices (point data) or faces (cell data).
%
% Syntax:
%   export_mesh_to_vtk(filename, V, F)
%   export_mesh_to_vtk(filename, V, F, Name, Value, ...)
%
% Required Inputs:
%   filename - String specifying output VTK file path (e.g., 'mesh.vtk')
%   V        - [n×3] double array of vertex coordinates in mm
%              Each row contains [x, y, z] coordinates of a vertex
%   F        - [m×3] integer array of face connectivity (1-based indexing)
%              Each row contains indices into V defining a triangle
%
% Optional Name-Value Parameters:
%   'point_vectors'  - [n×3] double, vector field at vertices
%                      Common uses: surface tangent gradients, velocity fields
%                      Example: gradient of scalar signal on mesh vertices
%   
%   'point_scalars'  - [n×1] double, scalar field at vertices
%                      Common uses: signal values, magnitudes, curvature
%                      Example: EEG/MEG signal amplitudes, |∇x|
%   
%   'point_normals'  - [n×3] double, unit normal vectors at vertices
%                      Used for smooth surface rendering and lighting
%                      Should be unit-length vectors perpendicular to surface
%   
%   'cell_vectors'   - [m×3] double, vector field at face centers
%                      Common uses: per-face gradients, flow directions
%                      Example: discrete gradient computed per triangle
%
% Output:
%   Writes ASCII VTK file to disk (no return value)
%
% File Format:
%   - Legacy VTK POLYDATA format (ASCII)
%   - 0-based indexing in output file (converted from MATLAB's 1-based)
%   - Compatible with ParaView 3.0+ and other VTK viewers
%
% Usage Examples:
%
%   Example 1: Export basic mesh geometry only
%     export_mesh_to_vtk('brain.vtk', V, F);
%
%   Example 2: Export mesh with scalar signal at vertices
%     signal = sin(2*pi*0.1*sqrt(sum(V.^2, 2)));  % radial pattern
%     export_mesh_to_vtk('signal.vtk', V, F, 'point_scalars', signal);
%
%   Example 3: Export mesh with gradient vectors at vertices
%     [grad_x, grad_y, grad_z] = compute_gradient(V, F, signal);
%     grad_vert = [grad_x, grad_y, grad_z];
%     export_mesh_to_vtk('gradient.vtk', V, F, 'point_vectors', grad_vert);
%
%   Example 4: Export mesh with multiple data fields
%     export_mesh_to_vtk('full_data.vtk', V, F, ...
%         'point_scalars', signal, ...
%         'point_vectors', grad_vert, ...
%         'point_normals', vertex_normals, ...
%         'cell_vectors', face_gradients);
%
%   Example 5: Export time series as separate files
%     for t = 1:n_timepoints
%         fname = sprintf('mesh_t%04d.vtk', t);
%         export_mesh_to_vtk(fname, V, F, 'point_scalars', X(:,t));
%     end
%
% Visualization Workflow:
%   1. Export mesh with this function
%   2. Open VTK file in ParaView or similar viewer
%   3. Apply filters: Glyph (for vectors), WarpByScalar, etc.
%   4. Adjust color maps, lighting, and camera for publication figures
%
% Technical Notes:
%   - VTK uses 0-based indexing; MATLAB's 1-based F is converted automatically
%   - Vertex coordinates should be in physical units (mm recommended)
%   - All vector fields should have 3 components (x, y, z)
%   - Scalar fields must be column vectors [n×1]
%   - Legacy format chosen for maximum compatibility vs modern XML formats
%
% See also: triangulation, surfaceMesh, compute_phase_gradient_on_mesh

  p = inputParser;
  p.addParameter('point_vectors', []);
  p.addParameter('point_scalars', []);
  p.addParameter('cell_vectors',  []);
  p.addParameter('point_normals', []);
  p.parse(varargin{:});
  PV = p.Results.point_vectors;
  PS = p.Results.point_scalars;
  CV = p.Results.cell_vectors;
  PN = p.Results.point_normals;

  V = double(V); F = double(F);
  if size(F,2) ~= 3, error('F must be m×3 triangles'); end
  n = size(V,1); m = size(F,1);

  % VTK uses 0-based indices
  F0 = F - 1;

  fid = fopen(filename,'w');
  assert(fid>0, 'Could not open file for writing: %s', filename);

  fprintf(fid, '# vtk DataFile Version 3.0\n');
  fprintf(fid, 'bioctree surface export\n');
  fprintf(fid, 'ASCII\n');
  fprintf(fid, 'DATASET POLYDATA\n');

  % Points
  fprintf(fid, 'POINTS %d float\n', n);
  fprintf(fid, '%.9g %.9g %.9g\n', V.' );

  % Polygons (POLYGONS m m*4; each line: "3 i j k")
  fprintf(fid, 'POLYGONS %d %d\n', m, m*4);
  fprintf(fid, '3 %d %d %d\n', F0.' );

  % Point data
  if ~isempty(PV) || ~isempty(PS) || ~isempty(PN)
    fprintf(fid, 'POINT_DATA %d\n', n);
    if ~isempty(PV)
      if size(PV,2)~=3 || size(PV,1)~=n, error('point_vectors must be n×3'); end
      fprintf(fid, 'VECTORS grad float\n');
      fprintf(fid, '%.9g %.9g %.9g\n', PV.' );
    end
    if ~isempty(PN)
      if size(PN,2)~=3 || size(PN,1)~=n, error('point_normals must be n×3'); end
      fprintf(fid, 'NORMALS vertex_normals float\n');
      fprintf(fid, '%.9g %.9g %.9g\n', PN.' );
    end
    if ~isempty(PS)
      if size(PS,2)~=1 || size(PS,1)~=n, error('point_scalars must be n×1'); end
      fprintf(fid, 'SCALARS scalar float 1\n');
      fprintf(fid, 'LOOKUP_TABLE default\n');
      fprintf(fid, '%.9g\n', PS );
    end
  end

  % Cell data
  if ~isempty(CV)
    if size(CV,2)~=3 || size(CV,1)~=m, error('cell_vectors must be m×3'); end
    fprintf(fid, 'CELL_DATA %d\n', m);
    fprintf(fid, 'VECTORS grad_face float\n');
    fprintf(fid, '%.9g %.9g %.9g\n', CV.' );
  end

  fclose(fid);
end
