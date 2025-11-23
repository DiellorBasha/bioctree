%% DGW Dictionary Demo Using JSON Keys
% This script shows how to:
%  1) Create and populate a DGW-style dictionary using JSON-encoded keys
%  2) Query the dictionary by band, spatial scale, temporal scale, velocity
%  3) Retrieve kernels and show meaningful usage

clear atomDict

%% 1. Create dictionary
atomDict = configureDictionary("string","struct");

%% 2. Define parameter grids (toy example)
bands          = ["delta","alpha","beta"];
spatialScales  = [1 2];
temporalScales = [1 2];
velocities     = [0.0 0.5 1.0];   % standing → slow → fast

nLambda = 6;   % toy graph spectral dimension
nOmega  = 12;  % toy temporal spectral dimension

%% 3. Populate dictionary
for ib = 1:numel(bands)
    bandLabel = bands(ib);

    for iSx = 1:numel(spatialScales)
        sx = spatialScales(iSx);

        for iSt = 1:numel(temporalScales)
            st = temporalScales(iSt);

            for iA = 1:numel(velocities)
                alpha = velocities(iA);

                % Placeholder kernel (in real DGW: computed from GFT × DFT)
                K = randn(nLambda, nOmega);

                % Build value struct
                atomDef = struct();
                atomDef.band          = bandLabel;
                atomDef.spatialScale  = sx;
                atomDef.temporalScale = st;
                atomDef.velocity      = alpha;
                atomDef.kernel        = K;

                % Build JSON key
                keyStruct = struct();
                keyStruct.band          = bandLabel;
                keyStruct.spatialScale  = sx;
                keyStruct.temporalScale = st;
                keyStruct.velocity      = alpha;

                key = jsonencode(keyStruct);

                % Insert into dictionary
                atomDict(key) = atomDef;
            end
        end
    end
end

disp("Dictionary populated with DGW atom definitions.");
disp("Total entries: " + numEntries(atomDict));

%% 4. Query examples

keysList = keys(atomDict);

%% Print all keys with decoded info
for i = 1:numel(keysList)
    k = keysList(i);          % scalar string
    ks = jsondecode(k);       % valid JSON
    fprintf("Band=%s | s_x=%d | s_t=%d | v=%.1f\n", ...
        ks.band, ks.spatialScale, ks.temporalScale, ks.velocity);
end


%% Example A — Get all alpha-band atoms
disp("==== All alpha-band atoms ====");
for i = 1:numel(keysList)
    k = keysList(i);             % scalar string key
    ks = jsondecode(k);          % decode JSON
    if ks.band == "alpha"
        atom = atomDict(k);      % dictionary lookup
        fprintf("key=%s | sx=%d | st=%d | alpha=%.1f\n", ...
            k, atom.spatialScale, atom.temporalScale, atom.velocity);
    end
end


%% Example B — All atoms with spatialScale = 2
disp("==== All atoms with spatialScale = 2 ====");
for i = 1:numel(keysList)
    k = keysList(i);
    ks = jsondecode(k);
    if ks.spatialScale == 2
        atom = atomDict(k);
        fprintf("band=%s | st=%d | velocity=%.1f\n", ...
            atom.band, atom.temporalScale, atom.velocity);
    end
end


%% Example C — All beta-band atoms with velocity > 0.5
disp("==== All beta-band fast atoms (velocity > 0.5) ====");
for i = 1:numel(keysList)
    k = keysList(i);
    ks = jsondecode(k);
    if ks.band == "beta" && ks.velocity > 0.5
        atom = atomDict(k);
        fprintf("sx=%d | st=%d | alpha=%.1f\n", ...
            atom.spatialScale, atom.temporalScale, atom.velocity);
    end
end


%% 5. Retrieve and use a specific atom
% Let's pick alpha band, spatialScale=1, temporalScale=2, velocity=0.5

queryStruct = struct();
queryStruct.band          = "alpha";
queryStruct.spatialScale  = 1;
queryStruct.temporalScale = 2;
queryStruct.velocity      = 0.5;

queryKey = jsonencode(queryStruct);

if isKey(atomDict, queryKey)
    disp("==== Retrieved specific DGW atom ====");
    atom = atomDict(queryKey)
    
    % Example: apply kernel to a toy joint spectrum
    X_hat = randn(nLambda, nOmega);
    Y_hat = atom.kernel .* X_hat;
    fprintf("Filtered joint spectrum: size %dx%d\n", size(Y_hat,1), size(Y_hat,2));
else
    warning("Key not found: %s", queryKey);
end

