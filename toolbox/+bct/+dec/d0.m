function op = d0(DEC)
%D0 Exterior derivative operator (0-forms → 1-forms)
%
% Syntax:
%   op = bct.dec.d0(DEC)
%
% Inputs:
%   DEC - bct.DEC object
%
% Returns:
%   op - [E×V] sparse exterior derivative matrix
%
% Notes:
%   - Maps vertex-based 0-forms to edge-based 1-forms
%   - Pass-through accessor to DECLab backend.d0
%
% See also: bct.dec.d1, bct.dec.gradient

arguments
    DEC (1,1) bct.DEC
end

op = DEC.Backend.d0;

end
