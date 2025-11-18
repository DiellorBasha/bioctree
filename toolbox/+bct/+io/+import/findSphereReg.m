function sphere_reg_path = findSphereReg(surf_path)
%FINDSPHERERG Find corresponding .sphere.reg file for FreeSurfer surface
%
%   sphere_reg_path = findSphereReg(surf_path) attempts to locate the
%   corresponding spherical registration file for a FreeSurfer surface.
%
%   For example, given 'test-data/freesurfer/fsaverage/surf/lh.pial',
%   it will look for 'test-data/freesurfer/fsaverage/surf/lh.sphere.reg'
%
%   Returns:
%     sphere_reg_path - Full path to .sphere.reg file, or empty string if not found
%
%   See also: bct.io.import.mesh, bct.io.import.computeUVFromSphere

    sphere_reg_path = '';
    
    % Parse the input path
    [surf_dir, surf_file, surf_ext] = fileparts(surf_path);
    
    % Reconstruct full filename (file + extension)
    full_filename = [surf_file surf_ext];
    
    % Determine hemisphere prefix (lh or rh)
    if startsWith(full_filename, 'lh.')
        hemi = 'lh';
    elseif startsWith(full_filename, 'rh.')
        hemi = 'rh';
    else
        % No hemisphere prefix found
        return;
    end
    
    % Construct .sphere.reg filename
    sphere_reg_file = [hemi '.sphere.reg'];
    sphere_reg_candidate = fullfile(surf_dir, sphere_reg_file);
    
    % Check if file exists
    if isfile(sphere_reg_candidate)
        sphere_reg_path = sphere_reg_candidate;
    end
end
