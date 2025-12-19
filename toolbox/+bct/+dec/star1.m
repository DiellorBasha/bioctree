function op = star1(DEC)
%STAR1 Hodge star operator for 1-forms
%
% Syntax:
%   op = bct.dec.star1(DEC)
%
% Inputs:
%   DEC - bct.DEC object
%
% Returns:
%   op - [E×E] sparse diagonal Hodge star matrix
%
% Notes:
%   - Maps primal 1-forms to dual 1-forms
%   - Inner product for 1-forms
%   - Pass-through accessor to DECLab backend.hd1
%
% See also: bct.dec.star0, bct.dec.star2

arguments
    DEC (1,1) bct.DEC
end

op = DEC.Backend.hd1;

end
