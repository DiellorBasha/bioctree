% Recursive function to build the tree
function node = buildNode(C, S, level, pos)
   waveletName = 'bior4.4';

% Extract detail coefficients at this level
    LH = detcoef2('h', C, S, level);
    HL = detcoef2('v', C, S, level);
    HH = detcoef2('d', C, S, level);
    LL = appcoef2(C, S, waveletName, level);
    
    % Store node info
    node.level = level;
    node.pos = pos;
    node.LH = LH;
    node.HL = HL;
    node.HH = HH;
    node.LL = LL;
    
    % Recur for child nodes if not at lowest level
    if level > 1
        % Each child is 1/4th the size
        node.children = cell(4, 1);
        for i = 1:4
            node.children{i} = buildNode(C, S, level-1, [pos, i]);
        end
    else
        node.children = {};
    end
end
