function restoreFigureCallbacks(fig, token)
%BCT.UI.MANIFOLD.RESTOREFIGURECALLBACKS  Restore figure callbacks from token

    arguments
        fig (1,1) matlab.ui.Figure
        token (1,1) struct
    end

    fns = fieldnames(token);
    for i = 1:numel(fns)
        fn = fns{i};
        if isprop(fig, fn)
            fig.(fn) = token.(fn);
        end
    end
end
