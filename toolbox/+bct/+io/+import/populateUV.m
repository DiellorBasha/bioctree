function populateUV(manifold_obj, source_path)
%POPULATEUV Populate UV parametrization for a Manifold object
%
%   bct.io.import.populateUV(manifold_obj, source_path)
%
%   Computes UV parametrization from FreeSurfer .sphere.reg file and
%   populates the UV property of a Manifold object. This function is
%   typically called after mesh import when UV parametrization is needed.
%
%   Parameters:
%     manifold_obj - bct.manifold.Manifold object to populate
%     source_path  - Path to the surface file (used to find .sphere.reg)
%
%   The function:
%     1. Searches for corresponding .sphere.reg file in same directory
%     2. Loads spherical coordinates from .sphere.reg
%     3. Computes UV parametrization using spherical coordinate conversion
%     4. Sets manifold_obj.UV to the computed [N×2] UV coordinates
%
%   UV Computation Algorithm:
%     Given sphere coordinates (x, y, z):
%       theta = atan2(y, x)      % Azimuthal angle [-π, π]
%       phi   = acos(z)          % Polar angle [0, π]
%       u = (theta + π) / (2π)   % Normalize to [0, 1]
%       v = phi / π              % Normalize to [0, 1]
%
%   Errors:
%     - If .sphere.reg file not found
%     - If manifold_obj is not a mesh-type Manifold
%     - If sphere file cannot be read
%
%   Examples:
%     % Import mesh without UV, then add it later
%     B = bct.io.import.mesh('test-data/freesurfer/fsaverage/surf/lh.pial');
%     % ... do some work ...
%     % Now add UV parametrization when needed
%     bct.io.import.populateUV(B.Manifold, 'test-data/freesurfer/fsaverage/surf/lh.pial');
%
%     % Or use the convenience method on Manifold object directly
%     B.Manifold.computeUV('test-data/freesurfer/fsaverage/surf/lh.pial');
%
%   See also: bct.io.import.mesh, bct.io.import.computeUVFromSphere,
%             bct.io.import.findSphereReg, bct.manifold.Manifold.computeUV

    % Validate input
    if ~isa(manifold_obj, 'bct.manifold.Manifold')
        error('bct:io:import:InvalidInput', ...
            'First argument must be a bct.manifold.Manifold object');
    end
    
    if manifold_obj.Type ~= "mesh"
        error('bct:io:import:InvalidManifoldType', ...
            'UV parametrization only available for mesh-type Manifolds');
    end
    
    if nargin < 2 || isempty(source_path)
        error('bct:io:import:MissingPath', ...
            'source_path required to locate .sphere.reg file');
    end
    
    % Find corresponding .sphere.reg file
    sphere_reg_path = bct.io.import.findSphereReg(source_path);
    
    if isempty(sphere_reg_path)
        error('bct:io:import:SphereRegNotFound', ...
            'Could not find .sphere.reg file for: %s', source_path);
    end
    
    % Load sphere.reg file
    try
        sphere_raw = bct.io.in.readFreeSurferSurf(sphere_reg_path);
    catch ME
        error('bct:io:import:ReadFailed', ...
            'Failed to read sphere.reg file %s: %s', sphere_reg_path, ME.message);
    end
    
    % Validate vertex count matches
    N_surface = manifold_obj.N;
    N_sphere = size(sphere_raw.V, 1);
    
    if N_surface ~= N_sphere
        error('bct:io:import:VertexMismatch', ...
            'Vertex count mismatch: surface has %d vertices, sphere.reg has %d', ...
            N_surface, N_sphere);
    end
    
    % Compute UV parametrization
    UV = bct.io.import.computeUVFromSphere(sphere_raw.V);
    
    % Populate Manifold object
    manifold_obj.UV = UV;
    
    fprintf('  ✓ UV parametrization computed from: %s\n', sphere_reg_path);
end
