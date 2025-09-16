function exportRippleVideo(Z, x2, y2, t, filename, framerate)
% exportRippleVideo - Generate and save a 3D surface animation of ripple data
%
% Inputs:
%   Z         - [Ny x Nx x T] 3D wave amplitude volume
%   x2, y2    - Surface meshgrid coordinates
%   t         - Time vector
%   filename  - Output video filename (e.g., 'ripple_animation.mp4')
%   framerate - Frame rate of the video (default: 24)
%
% Example:
%   exportRippleVideo(Z, x2, y2, t, 'ripple_animation.mp4', 24)

    if nargin < 6
        framerate = 24;
    end

    v = VideoWriter(filename, 'MPEG-4');
    v.FrameRate = framerate;
    open(v);

    fig = figure('Visible', 'off');
    h = surf(x2, y2, Z(:,:,1), 'EdgeColor', 'none');
    zlim([-1 1]);
    axis equal tight;
    xlabel('x'); ylabel('y'); zlabel('Amplitude');
    view(30, 45);
    camlight; lighting gouraud;

    for ti = 1:size(Z,3)
        h.ZData = Z(:,:,ti);
        title('Wave Propagation on Flat Surface');
        subtitle(sprintf('t = %.2f s', t(ti)));
        drawnow;

        frame = getframe(fig);
        writeVideo(v, frame);
    end

    close(v);
    close(fig);
    fprintf('✅ Video saved as %s\n', filename);
end
