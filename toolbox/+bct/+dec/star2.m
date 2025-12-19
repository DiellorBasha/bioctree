function op = star2(DEC)
%STAR2 Hodge star operator for 2-forms
%
% Syntax:
%   op = bct.dec.star2(DEC)
%
% Inputs:
%   DEC - bct.DEC object
%
% Returns:
%   op - [F×F] sparse diagonal Hodge star matrix
%
% Notes:
%   - Maps primal 2-forms to dual 0-forms
%   - Inner product for 2-forms
%   - Pass-through accessor to DECLab backend.hd2
%
% See also: bct.dec.star0, bct.dec.star1

arguments
    DEC (1,1) bct.DEC
end

op = DEC.Backend.hd2;

end
