function ok = detectSymbols(depMeta)
%DETECTSYMBOLS Check if required symbols are available on path
%
% Inputs:
%   depMeta - Dependency metadata with requiredSymbols field
%
% Returns:
%   ok - true if all required symbols are found

requiredSymbols = depMeta.requiredSymbols;

for i = 1:numel(requiredSymbols)
    symbol = requiredSymbols{i};
    
    % Check if exists as file, class, or has been executed
    if exist(symbol, 'file') ~= 2 && exist(symbol, 'class') ~= 8
        ok = false;
        return;
    end
end

ok = true;

end
