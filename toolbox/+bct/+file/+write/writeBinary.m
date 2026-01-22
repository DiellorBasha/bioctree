function manifest = writeBinary(arrays, binPath, options)
%WRITEBINARY Write flattened arrays to binary file and generate manifest
%
% Syntax:
%   manifest = bct.file.write.writeBinary(arrays, binPath)
%   manifest = bct.file.write.writeBinary(arrays, binPath, options)
%
% Inputs:
%   arrays  - Cell array of structs from flattenStruct
%   binPath - Output path for binary file
%   options - Optional struct with fields:
%             .alignBytes - Byte alignment (default: 4)
%
% Outputs:
%   manifest - Structure with buffer metadata:
%              .buffers - Array of buffer entries with:
%                         .path, .dtype, .shape, .count, .byteOffset
%
% Description:
%   Writes all numeric arrays to a single binary file with optional
%   alignment padding between arrays. Returns manifest with byte offsets
%   for reconstructing data from binary file.
%
% Examples:
%   [arrays, ~] = bct.file.write.flattenStruct(s);
%   manifest = bct.file.write.writeBinary(arrays, 'data.bin');

arguments
    arrays (:,1) cell
    binPath (1,1) string
    options.alignBytes (1,1) {mustBePositive, mustBeInteger} = 4
end

align = uint32(options.alignBytes);

% Open binary file for writing
[fid, msg] = fopen(binPath, 'w');
if fid < 0
    error('bct:file:write:CannotOpenFile', ...
        'Cannot open %s for writing: %s', binPath, msg);
end

% Initialize tracking
offset = uint32(0);
manifest = struct();
manifest.buffers = [];

% Write each array with alignment
for i = 1:numel(arrays)
    A = arrays{i};
    
    % Apply alignment padding
    if align > 1
        pad = mod(double(align - mod(offset, align)), double(align));
        if pad ~= 0 && pad ~= double(align)
            fwrite(fid, zeros(pad, 1, 'uint8'), 'uint8');
            offset = offset + uint32(pad);
        end
    end
    
    % Create buffer entry
    entry = struct();
    entry.path = A.path;
    entry.dtype = A.dtype;
    entry.shape = A.shape;
    entry.count = uint32(numel(A.data));
    entry.byteOffset = offset;
    
    % Write data
    cls = bct.file.write.matlabClassForDtype(A.dtype);
    fwrite(fid, A.data, cls);
    
    % Update offset
    bytesWritten = uint32(numel(A.data) * bct.file.write.bytesPerElement(A.dtype));
    offset = offset + bytesWritten;
    
    % Add to manifest
    manifest.buffers = [manifest.buffers; entry]; %#ok<AGROW>
end

fclose(fid);

end
