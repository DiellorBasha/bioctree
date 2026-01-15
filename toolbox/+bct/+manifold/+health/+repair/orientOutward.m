function [F2, info] = orientOutward(V, F)
%ORIENTOUTWARD Ensure outward orientation for a closed (watertight) mesh using signed volume.
%
% Preconditions:
%   - Mesh should be consistently oriented already.
%   - Mesh should be watertight/closed; otherwise outward is not well-defined.
%
% If signed volume < 0, we flip all faces (swap columns 2 and 3).
%
a = V(F(:,1), :);
b = V(F(:,2), :);
c = V(F(:,3), :);

signedVolume = sum(dot(a, cross(b, c, 2), 2)) / 6;

F2 = F;
applied = false;

if signedVolume < 0
    F2(:, [2 3]) = F2(:, [3 2]);
    applied = true;
    signedVolumeAfter = -signedVolume;
else
    signedVolumeAfter = signedVolume;
end

info = struct();
info.applied = applied;
info.signedVolumeBefore = signedVolume;
info.signedVolumeAfter = signedVolumeAfter;
info.outward = (signedVolumeAfter > 0);

end
