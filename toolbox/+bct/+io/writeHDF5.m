function writeHDF5(B, filename)
%WRITEHDF5  Write BCT object data to HDF5 file
%
%   bct.io.writeHDF5(B, filename)
%
% This is the main HDF5 serialization function for bct objects.
% Called automatically by obj.save() method.
%
% Inputs:
%   B        - bct object to save
%   filename - Path to HDF5 file
%
% HDF5 Structure:
%   /manifold/vertices   - [N×3] mesh vertices
%   /manifold/faces      - [M×3] mesh faces
%   /lambda/values       - [K×1] eigenvalues
%   /lambda/U            - [N×K] eigenvectors (chunked)
%   /time/axis           - [T×1] time points
%   /time/fs             - Sampling frequency (attribute)
%   /metadata/...        - Version info, creation date
%
% Example:
%   bct.io.writeHDF5(B, 'data/bct/my_analysis.h5');
%
% See also: bct.save, bct.loadobj

% Delete existing file
if exist(filename, 'file')
  delete(filename);
end

% ------------------------
% Manifold (mesh geometry)
% ------------------------
if ~isempty(B.Manifold)
  V = B.Manifold.Vertices;
  F = B.Manifold.Faces;
  
  if ~isempty(V)
    h5create(filename, '/manifold/vertices', size(V), 'Datatype', 'double');
    h5write(filename, '/manifold/vertices', V);
  end
  
  if ~isempty(F)
    h5create(filename, '/manifold/faces', size(F), 'Datatype', 'int32');
    h5write(filename, '/manifold/faces', int32(F));
  end
  
  % Save manifold type
  h5writeatt(filename, '/manifold', 'N', B.Manifold.N);
end

% ------------------------
% Lambda (spectral domain)
% ------------------------
if ~isempty(B.Lambda) && ~isempty(B.Lambda.axis)
  lambda_vals = B.Lambda.axis;
  h5create(filename, '/lambda/values', size(lambda_vals), 'Datatype', 'double');
  h5write(filename, '/lambda/values', lambda_vals);
  
  % Save eigenvectors with chunking for performance
  if ~isempty(B.Lambda.U)
    U = B.Lambda.U;
    chunk_size = [size(U, 1), min(10, size(U, 2))];
    h5create(filename, '/lambda/U', size(U), ...
      'Datatype', 'double', 'ChunkSize', chunk_size);
    h5write(filename, '/lambda/U', U);
  end
  
  h5writeatt(filename, '/lambda', 'K', B.Lambda.K);
end

% ------------------------
% Time domain (optional)
% ------------------------
if ~isempty(B.Time)
  t_axis = B.Time.axis;
  h5create(filename, '/time/axis', size(t_axis), 'Datatype', 'double');
  h5write(filename, '/time/axis', t_axis);
  
  h5writeatt(filename, '/time', 'T', B.Time.T);
  h5writeatt(filename, '/time', 'fs', B.Time.fs);
  h5writeatt(filename, '/time', 'dt', B.Time.dt);
end

% ------------------------
% Metadata
% ------------------------
h5writeatt(filename, '/', 'class', 'bct');
h5writeatt(filename, '/', 'version', 1);
h5writeatt(filename, '/', 'created', datestr(now));
h5writeatt(filename, '/', 'matlab_version', version);

end
