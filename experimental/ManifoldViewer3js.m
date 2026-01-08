
% Create empty viewer
fig = uifigure('Position', [1458 61 1091 1339]);
gr = uigridlayout(fig, [1 1]);
gr.RowHeight = {'1x'};
gr.ColumnWidth = {'1x'};
v = bct.ui.manifold.Viewer(gr);  % Empty - no mesh loaded
v.setMesh(M);
%% 
fScalar = f0;
v.setScalar(fScalar);
v.setScalar([]);