classdef In
  methods (Static)
function raw = readFreeSurferSurf(fname)
  % ---- FreeSurfer magic numbers ----
  TRI  = 16777214;          % triangle (.pial/.white/etc)
  QUAD = 16777215;          % old quad format
  NQ   = 16777213;          % ▶ NEW_QUAD_FILE_MAGIC_NUMBER (-3 & 0x00ffffff)

  fid = fopen(fname,'rb','b');        % big-endian
  if fid<0, error('Cannot open %s',fname); end
  magic = bct.io.graph.In.fread3(fid);
  switch magic
    case QUAD
      Nv = bct.io.graph.In.fread3(fid);
      Nf = bct.io.graph.In.fread3(fid);
      V  = fread(fid, Nv*3, 'int16') ./ 100;
      F  = zeros(Nf,4,'int32');
      for k=1:Nf
        F(k,1)=bct.io.graph.In.fread3(fid);
        F(k,2)=bct.io.graph.In.fread3(fid);
        F(k,3)=bct.io.graph.In.fread3(fid);
        F(k,4)=bct.io.graph.In.fread3(fid);
      end
    case NQ  % ▶ handle NEW_QUAD same as QUAD
      Nv = bct.io.graph.In.fread3(fid);
      Nf = bct.io.graph.In.fread3(fid);
      V  = fread(fid, Nv*3, 'int16') ./ 100;
      F  = zeros(Nf,4,'int32');
      for k=1:Nf
        F(k,1)=bct.io.graph.In.fread3(fid);
        F(k,2)=bct.io.graph.In.fread3(fid);
        F(k,3)=bct.io.graph.In.fread3(fid);
        F(k,4)=bct.io.graph.In.fread3(fid);
      end
    case TRI
      fgets(fid); fgets(fid);                 % skip 2 header lines
      Nv = fread(fid,1,'int32');
      Nf = fread(fid,1,'int32');
      V  = fread(fid, Nv*3, 'float32');
      Ft = fread(fid, Nf*3, 'int32');
      F  = reshape(Ft,3,Nf).';
    otherwise
      fclose(fid);
      error('Unknown FreeSurfer magic number (%d) in %s', magic, fname);
  end
  V = reshape(V,3,[]).';
  fclose(fid);
  % 0-based → 1-based
  F = F + 1;
  raw = struct('V',double(V),'F',int32(F), ...
               'meta',struct('source','freesurfer','file',string(fname), ...
                             'isQuad', size(F,2)==4));
end
  end

  methods (Static, Access=private)
    % function x = fread3(fid)
    %   b = fread(fid,3,'uint8'); if numel(b)<3, error('EOF fread3'); end
    %   x = bitshift(uint32(b(1)),16)+bitshift(uint32(b(2)),8)+uint32(b(3));
    %   if x >= 2^23, x = int32(double(x)-2^24); else, x=int32(x); end
    %   x = double(x);
    % end
function x = fread3(fid)
% Read a 24-bit big-endian unsigned integer and return as double [0..2^24-1]
b1 = fread(fid, 1, 'uchar');   % MSB
b2 = fread(fid, 1, 'uchar');
b3 = fread(fid, 1, 'uchar');   % LSB
if numel([b1 b2 b3]) < 3
    error('bct:io:fread3:EOF','Unexpected EOF while reading 3-byte int.');
end
x = double(bitshift(uint32(b1),16) + bitshift(uint32(b2),8) + uint32(b3));
end

  end
end
