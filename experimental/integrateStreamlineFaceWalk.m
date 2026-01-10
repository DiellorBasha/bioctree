function streamline = integrateStreamlineFaceWalk(TR, v_f, face0, bc0, dt, nSteps)

streamline = zeros(nSteps,3);
face = face0;
bc   = bc0;

for k = 1:nSteps
    [face, bc, pos] = stepFaceWalk(TR, v_f, face, bc, dt);
    streamline(k,:) = pos;
end
end
