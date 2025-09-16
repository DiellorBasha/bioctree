function plotNode(node)
    if isempty(node) || ~isfield(node, 'Valid') || ~node.Valid
        return;
    end

    % Draw stored rectangle
    r = node.Rectangle;
    rectangle('Position', r, 'EdgeColor', 'r', 'LineWidth', 1.5);

    % Recurse if children exist
    if isfield(node, 'children') && ~isempty(node.children)
        for i = 1:length(node.children)
            plotNode(node.children{i});
        end
    end
end
