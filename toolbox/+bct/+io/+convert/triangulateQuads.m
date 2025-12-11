function Ft = triangulateQuads(Fq)
%TRIANGULATEQUADS Convert quad faces to triangle faces
%
%   Ft = triangulateQuads(Fq) splits each quad face into two triangles
%
%   For quad [a b c d], creates triangles:
%     [a b c] and [a c d]
%
%   Inputs:
%     Fq - Mx4 quad faces
%
%   Returns:
%     Ft - (2M)x3 triangle faces

    if isempty(Fq) || size(Fq, 2) ~= 4
        Ft = Fq;
        return;
    end
    
    a = Fq(:,1);
    b = Fq(:,2);
    c = Fq(:,3);
    d = Fq(:,4);
    
    Ft = [a b c; a c d];
end
