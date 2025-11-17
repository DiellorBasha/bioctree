function raw = readFreeSurferSurf(fname)
%READFREESURFERSURF Read FreeSurfer surface file
%
%   raw = readFreeSurferSurf(fname) reads a FreeSurfer surface file
%   and returns a raw structure with vertices, faces, and metadata.
%
%   Supports:
%     - Triangle meshes (standard format)
%     - Quad meshes (old format)
%     - New quad format
%
%   Returns:
%     raw.V     - Nx3 vertices (double, 1-indexed)
%     raw.F     - Mx3 or Mx4 faces (int32, 1-indexed)
%     raw.meta  - Metadata structure

    % FreeSurfer magic numbers
    TRI  = 16777214;  % triangle (.pial/.white/etc)
    QUAD = 16777215;  % old quad format
    NQ   = 16777213;  % NEW_QUAD_FILE_MAGIC_NUMBER

    fid = fopen(fname, 'rb', 'b');  % big-endian
    if fid < 0
        error('bct:io:in:CannotOpenFile', 'Cannot open %s', fname);
    end
    
    magic = fread3(fid);
    
    switch magic
        case {QUAD, NQ}
            % Quad format
            Nv = fread3(fid);
            Nf = fread3(fid);
            V  = fread(fid, Nv*3, 'int16') ./ 100;
            F  = zeros(Nf, 4, 'int32');
            for k = 1:Nf
                F(k,1) = fread3(fid);
                F(k,2) = fread3(fid);
                F(k,3) = fread3(fid);
                F(k,4) = fread3(fid);
            end
            
        case TRI
            % Triangle format
            fgets(fid);  % skip header line 1
            fgets(fid);  % skip header line 2
            Nv = fread(fid, 1, 'int32');
            Nf = fread(fid, 1, 'int32');
            V  = fread(fid, Nv*3, 'float32');
            Ft = fread(fid, Nf*3, 'int32');
            F  = reshape(Ft, 3, Nf).';
            
        otherwise
            fclose(fid);
            error('bct:io:in:UnknownMagicNumber', ...
                'Unknown FreeSurfer magic number (%d) in %s', magic, fname);
    end
    
    V = reshape(V, 3, []).';
    fclose(fid);
    
    % Convert from 0-based to 1-based indexing
    F = F + 1;
    
    % Build output structure
    raw = struct(...
        'V', double(V), ...
        'F', int32(F), ...
        'meta', struct(...
            'source', 'freesurfer', ...
            'file', string(fname), ...
            'isQuad', size(F,2) == 4 ...
        ) ...
    );
end

function x = fread3(fid)
    % Read a 24-bit big-endian unsigned integer
    b1 = fread(fid, 1, 'uchar');  % MSB
    b2 = fread(fid, 1, 'uchar');
    b3 = fread(fid, 1, 'uchar');  % LSB
    
    if numel([b1 b2 b3]) < 3
        error('bct:io:in:UnexpectedEOF', ...
            'Unexpected EOF while reading 3-byte integer');
    end
    
    x = double(bitshift(uint32(b1), 16) + bitshift(uint32(b2), 8) + uint32(b3));
end
