function writeManifest(manifest, jsonPath)
%WRITEMANIFEST Write JSON manifest file
%
% Syntax:
%   bct.file.write.writeManifest(manifest, jsonPath)
%
% Inputs:
%   manifest - Structure containing metadata and buffer information
%   jsonPath - Output path for JSON manifest file
%
% Description:
%   Writes the manifest structure as a formatted JSON file.
%   The JSON contains schema information and byte offsets for
%   reconstructing data from the binary file.
%
% Examples:
%   bct.file.write.writeManifest(manifest, 'data.json');

arguments
    manifest (1,1) struct
    jsonPath (1,1) string
end

% Encode as JSON with pretty printing
txt = jsonencode(manifest, 'PrettyPrint', true);

% Write to file
[fid, msg] = fopen(jsonPath, 'w');
if fid < 0
    error('bct:file:write:CannotOpenFile', ...
        'Cannot open %s for writing: %s', jsonPath, msg);
end

fwrite(fid, txt, 'char');
fclose(fid);

end
