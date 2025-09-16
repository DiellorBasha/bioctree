function plotBrainConnectivity(A)
figure
imagesc(log(A));
colorbar;
cbar = colorbar;
cbar.Label.String = "log(A)";
title("Connectivity Weights of Brain Regions (log scale)")
xlabel("Brain Region Index (Left: 1-180 - Right: 181-360)")
ylabel("Brain Region Index (Left: 1-180 - Right: 181-360)")
end
