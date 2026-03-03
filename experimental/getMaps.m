csvDir = "C:\CodingProjects\bioctree\external\Colormaps_MATLAB\Codes and data files";

mapNames = [

    "viridis"
    "inferno"
    "plasma"
    "blackbody"
    "kindlmann"
    "moreland"
    "coolwarm"    % will alias to bentcoolwarm CSV
    "parula"
    "turbo"
    "hot"
    "cool"
    "summer"
    "spring"
    "winter"
    "bone"
    "copper"
];

outPng = fullfile(pwd, "data/colormaps_atlas.png");

writeColormapAtlasPNG(outPng, mapNames, 256, csvDir);
