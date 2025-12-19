function op = star0(DEC)
%STAR0 Hodge star operator for 0-forms
%
% Syntax:
%   op = bct.dec.star0(DEC)
%
% Inputs:
%   DEC - bct.DEC object
%
% Returns:
%   op - [V×V] sparse diagonal Hodge star matrix
%
% Notes:
%   - Maps primal 0-forms to dual 2-forms
%   - Inner product for 0-forms
%   - Pass-through accessor to DECLab backend.hd0
%
% See also: bct.dec.star1, bct.dec.star2

arguments
    DEC (1,1) bct.DEC
end

op = DEC.Backend.hd0;

end
