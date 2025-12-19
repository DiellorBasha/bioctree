function op = d1(DEC)
%D1 Exterior derivative operator (1-forms → 2-forms)
%
% Syntax:
%   op = bct.dec.d1(DEC)
%
% Inputs:
%   DEC - bct.DEC object
%
% Returns:
%   op - [F×E] sparse exterior derivative matrix
%
% Notes:
%   - Maps edge-based 1-forms to face-based 2-forms
%   - Pass-through accessor to DECLab backend.d1
%
% See also: bct.dec.d0, bct.dec.curl

arguments
    DEC (1,1) bct.DEC
end

op = DEC.Backend.d1;

end
