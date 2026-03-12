function applyPlotDefaults(fig)
%APPLYPLOTDEFAULTS  Apply standard plot styling to all axes in a figure.
%
%   applyPlotDefaults()       — applies to current figure (gcf)
%   applyPlotDefaults(fig)    — applies to specified figure handle
%
%   Sets on every axes in the figure:
%     FontSize  = 14
%     TickDir   = 'out'
%     grid      = off
%     PlotBoxAspectRatio = [1 1 1]   (square axes)
%
%   Also adjusts the figure window to a square aspect ratio.
%
%   Call this at the end of any plotting function to enforce consistent
%   visual defaults.

    if nargin < 1
        fig = gcf;
    end

    % Square figure window
    pos = fig.Position;
    side = max(pos(3), pos(4));
    fig.Position = [pos(1), pos(2), side, side];

    axList = findall(fig, 'Type', 'axes');
    for i = 1:numel(axList)
        set(axList(i), 'FontSize', 14, 'TickDir', 'out');
        grid(axList(i), 'off');
        % Square axes (preserves tick scaling, unlike 'axis square')
        set(axList(i), 'PlotBoxAspectRatio', [1 1 1]);
    end
end
