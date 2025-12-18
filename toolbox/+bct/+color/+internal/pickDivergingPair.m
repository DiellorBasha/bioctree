function [negColor, posColor] = pickDivergingPair(index)
%PICKDIVERGINGPAIR  Select opposing hues for diverging maps
%   Uses color theory to select complementary hues

    % Define perceptually-balanced diverging pairs
    pairs = [
        0.0, 0.4, 0.8,   0.8, 0.2, 0.0;  % Blue-Red (classic)
        0.0, 0.6, 0.6,   0.9, 0.4, 0.0;  % Cyan-Orange
        0.4, 0.0, 0.6,   0.6, 0.8, 0.0;  % Purple-Yellow-Green
        0.8, 0.0, 0.4,   0.0, 0.6, 0.4;  % Magenta-Green
        0.2, 0.2, 0.8,   0.9, 0.6, 0.2;  % Blue-Gold
    ];
    
    % Wrap index
    index = mod(index-1, size(pairs,1)) + 1;
    
    negColor = pairs(index, 1:3);
    posColor = pairs(index, 4:6);
end
