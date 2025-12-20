function token = installFigureCallbacks(fig, callbacks)
%BCT.UI.MANIFOLD.INSTALLFIGURECALLBACKS  Install figure callbacks with restore token
%
% token = bct.ui.manifold.installFigureCallbacks(fig, callbacks)
%
% callbacks is a struct with fields:
%   WindowButtonMotionFcn
%   WindowButtonUpFcn
%   WindowScrollWheelFcn
%   WindowKeyPressFcn
%
% token stores previous values for restoration.

    arguments
        fig (1,1) matlab.ui.Figure
        callbacks (1,1) struct
    end

    token = struct();
    fns = fieldnames(callbacks);

    for i = 1:numel(fns)
        fn = fns{i};
        if isprop(fig, fn)
            token.(fn) = fig.(fn);
            fig.(fn) = callbacks.(fn);
        end
    end
end
