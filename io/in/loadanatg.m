function anat= loadanatg()
%LOADANATG Summary of this function goes here
%   Detailed explanation goes here
test_data='C:\CodingProjects\bioctree\test-data';
paths={"sub-MTL0002","sub-MTL0005","sub-MTL0010","sub-MTL0015","sub-MTL0018"};
for k =1:length(paths)
    G=load(fullfile(test_data, paths{k}, "gspanat.mat"));
    anat(k).G=G.G;
    bstanat=load(fullfile(test_data, paths{k}, "anat.mat"));
    anat(k).G.plotting.vertex_size = 5;
    anat(k).bst = bstanat.anat;
    anat(k).sulci=bstanat.anat.SulciMap;
    anat(k).curv=bstanat.anat.Curvature;
end

