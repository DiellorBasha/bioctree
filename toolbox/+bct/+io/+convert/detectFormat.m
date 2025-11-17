function format = detectFormat(path)
%DETECTFORMAT Auto-detect file format from path/extension
%
%   format = detectFormat(path) returns format string based on file
%
%   Returns:
%     'FreeSurfer' - FreeSurfer surface file
%     'Brainstorm' - Brainstorm anatomy file
%     'unknown'    - Cannot determine

    [~, fname, ext] = fileparts(path);
    
    % Check for Brainstorm patterns
    % 1. tess_*.mat files
    if startsWith(fname, 'tess_') && strcmpi(ext, '.mat')
        format = 'Brainstorm';
        return;
    end
    
    % 2. Directory paths containing 'brainstorm' or 'anat'
    if exist(path, 'dir') && (contains(path, 'brainstorm') || contains(path, 'anat'))
        format = 'Brainstorm';
        return;
    end
    
    % 3. Protocol directory structure (has anat/ subdirectory)
    if exist(path, 'dir') && exist(fullfile(path, 'anat'), 'dir')
        format = 'Brainstorm';
        return;
    end
    
    % Check for FreeSurfer patterns
    if isempty(ext) || any(contains(path, {'.pial', '.white', '.inflated', '.sphere', '.orig'}))
        format = 'FreeSurfer';
        return;
    end
    
    % Check for generic MATLAB files (could be Brainstorm)
    if strcmpi(ext, '.mat')
        format = 'Brainstorm';
        return;
    end
    
    % Default to FreeSurfer for unrecognized
    format = 'FreeSurfer';
end
