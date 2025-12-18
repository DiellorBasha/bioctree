function color = pickColor(index)
%PICKCOLOR  Select a categorical base color by index
%
%   Internal helper. No semantic meaning.

    % Use a stable categorical palette
    P = lines(12);   % 12 visually distinct colors

    % Wrap index
    index = mod(index-1, size(P,1)) + 1;

    color = P(index,:);
end
