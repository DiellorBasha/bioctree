function node = subdivideBlock(powerMap, tRange, fRange, threshold, minSize, time, f)
    % Validate ranges
    Nf = size(powerMap, 1);
    Nt = size(powerMap, 2);

    tRange = tRange(tRange >= 1 & tRange <= Nt);
    fRange = fRange(fRange >= 1 & fRange <= Nf);

    if isempty(tRange) || isempty(fRange)
        node = []; return;
    end

    % Extract block and measure complexity
    block = powerMap(fRange, tRange);
    value = std(block(:));

    % Convert ranges to physical coordinates
    t1 = time(min(tRange));
    t2 = time(max(tRange));
    f1 = f(min(fRange));
    f2 = f(max(fRange));

    % Ensure ascending frequency bounds for plotting
    tMin = min([t1, t2]);
    tMax = max([t1, t2]);
    fMin = min([f1, f2]);
    fMax = max([f1, f2]);

    width = tMax - tMin;
    height = fMax - fMin;

    % Store info in node
    node.tRange = tRange;
    node.fRange = fRange;
    node.value = value;
    node.Rectangle = [tMin, fMin, width, height];
    node.Valid = (width > 0 && height > 0);

    % Base case: stop subdivision
    if value < threshold || length(tRange) <= minSize || length(fRange) <= minSize
        node.children = {};
        return;
    end

    % Recursive subdivision: split ranges
    midT = floor(length(tRange)/2);
    midF = floor(length(fRange)/2);
    tSplits = {tRange(1:midT), tRange(midT+1:end)};
    fSplits = {fRange(1:midF), fRange(midF+1:end)};

    childIdx = 1;
    for fi = 1:2
        for ti = 1:2
            node.children{childIdx} = subdivideBlock(...
                powerMap, tSplits{ti}, fSplits{fi}, ...
                threshold, minSize, time, f);
            childIdx = childIdx + 1;
        end
    end
end
