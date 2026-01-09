function E_reordered = reorder(E, ordering)
%REORDER Change eigenvalue ordering of Eigenpairs
%
% Syntax:
%   E_asc = bct.eigenpairs.reorder(E, 'ascending')
%   E_desc = bct.eigenpairs.reorder(E, 'descending')
%   E_custom = bct.eigenpairs.reorder(E, indices)
%
% Inputs:
%   E        - bct.Eigenpairs object
%   ordering - 'ascending', 'descending', or [k×1] index vector
%
% Outputs:
%   E_reordered - New Eigenpairs with reordered modes
%
% Examples:
%   % Sort descending by eigenvalue
%   E_desc = bct.eigenpairs.reorder(E, 'descending');
%   
%   % Custom order (e.g., by significance)
%   [~, idx] = sort(abs(E.project(signal)), 'descend');
%   E_sig = bct.eigenpairs.reorder(E, idx);
%
% See also: bct.Eigenpairs

arguments
    E        bct.Eigenpairs
    ordering {mustBeOrderingSpec(ordering, E)}
end

% Determine reordering indices
if isstring(ordering) || ischar(ordering)
    ordering = string(ordering);
    switch ordering
        case "ascending"
            [~, idx] = sort(E.Values, 'ascend');
        case "descending"
            [~, idx] = sort(E.Values, 'descend');
        otherwise
            error('bct:eigenpairs:InvalidOrdering', ...
                'Ordering must be "ascending", "descending", or index vector');
    end
else
    idx = ordering;
end

% Apply reordering
E_reordered = bct.Eigenpairs(...
    E.Values(idx), ...
    E.Vectors(:, idx), ...
    E.MassMatrix, ...
    'operator', E.Operator, ...
    'basis', E.Basis, ...
    'manifoldID', E.ManifoldID);

end

function mustBeOrderingSpec(ordering, E)
    if isstring(ordering) || ischar(ordering)
        ordering = string(ordering);
        assert(ismember(ordering, ["ascending", "descending"]), ...
            'Ordering string must be "ascending" or "descending"');
    else
        % Must be index vector
        assert(isnumeric(ordering) && isvector(ordering), ...
            'Ordering must be string or numeric vector');
        assert(length(ordering) == E.numModes(), ...
            'Index vector must have length equal to number of modes');
        assert(all(ordering >= 1 & ordering <= E.numModes()), ...
            'Indices must be in range [1, %d]', E.numModes());
    end
end
