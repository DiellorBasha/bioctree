function format = detectFormat(source)
%DETECTFORMAT Auto-detect file format from path/extension
%
%   format = detectFormat(path) returns format string based on file
%
%   Returns:
%     'FreeSurfer' - FreeSurfer surface file
%     'Brainstorm' - Brainstorm anatomy file
%     'MATLAB'     - Generic MATLAB .mat file with V and F
%     'unknown'    - Cannot determine

    [~, fname, ext] = fileparts(source);
    
    % Check for Brainstorm patterns
    % 1. tess_*.mat files
    if startsWith(fname, 'tess_') && strcmpi(ext, '.mat')
        format = 'Brainstorm';
        return;
    end
    
    % 2. Directory paths containing 'brainstorm' or 'anat'
    if exist(source, 'dir') && (contains(source, 'brainstorm') || contains(source, 'anat'))
        format = 'Brainstorm';
        return;
    end
    
    % 3. Protocol directory structure (has anat/ subdirectory)
    if exist(source, 'dir') && exist(fullfile(source, 'anat'), 'dir')
        format = 'Brainstorm';
        return;
    end
    
    % Check for FreeSurfer patterns
    % FreeSurfer files can have extensions like .pial, .white, .inflated, etc.
    % or no extension at all
    freesurfer_extensions = {'.pial', '.white', '.inflated', '.sphere', '.orig'};
    if isempty(ext) || any(strcmpi(ext, freesurfer_extensions))
        format = 'FreeSurfer';
        return;
    end
    
    % Check for generic MATLAB files
    if strcmpi(ext, '.mat')
        % Try to determine if it's a generic MATLAB mesh (V, F) or Brainstorm
        if exist(source, 'file')
            try
                vars = whos('-file', source);
                varNames = {vars.name};
                % If has V and F but not Brainstorm-specific fields, it's MATLAB
                hasV = ismember('V', varNames);
                hasF = ismember('F', varNames);
                hasBrainstormFields = any(ismember({'Vertices', 'Faces', 'Comment'}, varNames));
                
                if hasV && hasF && ~hasBrainstormFields
                    format = 'MATLAB';
                    return;
                end
            catch
                % If can't read, default to Brainstorm
            end
        end
        % Default .mat to Brainstorm if not clearly MATLAB format
        format = 'Brainstorm';
        return;
    end
    
    % Default to FreeSurfer for unrecognized
    format = 'FreeSurfer';
end
