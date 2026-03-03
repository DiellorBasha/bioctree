function [amplitude, phase, t, bandInfo] = readHilbertBands(hTds, hilbertInfo, opts)
%READHILBERTBANDS Read Hilbert datastore and reorganize into per-band matrices.
%
%   [amplitude, phase, t, bandInfo] = readHilbertBands(hTds, hilbertInfo)
%   [amplitude, phase, t, bandInfo] = readHilbertBands(hTds, hilbertInfo, Name=Value)
%
%   Reads all channels from a Hilbert TransformedDatastore and pivots the
%   data from per-channel layout ([nSamples x 2*nBands] per channel) to
%   per-band layout ([nChannels x nSamples] per band).
%
%   This is the format needed for source mapping: K * bandMatrix projects
%   sensor-space band amplitude to source space.
%
%   Inputs:
%       hTds        - TransformedDatastore from hilbertTransform().
%                     Each read returns [nSamples x 2*nBands] for one
%                     channel (amplitude cols, then phase cols).
%       hilbertInfo - info struct from hilbertTransform(). Must contain:
%                     .bandNames, .amplitudeCols, .phaseCols, .sfreq,
%                     .nSamples, .nBands
%
%   Name-Value Arguments:
%       ChannelNames - [nChannels x 1] string array of channel names
%                      (default: auto from sdsGetChannelNames on the
%                      underlying datastore, or "ch1","ch2",...).
%       Verbose      - print progress (default true)
%
%   Outputs:
%       amplitude - struct with one field per band:
%                     .delta = [nChannels x nSamples]
%                     .theta = [nChannels x nSamples]
%                     .alpha = [nChannels x nSamples]
%                     .beta  = [nChannels x nSamples]
%                     .gamma = [nChannels x nSamples]
%                   Field names match hilbertInfo.bandNames.
%
%       phase     - struct with same layout as amplitude, containing
%                   instantaneous phase in radians (-pi to pi).
%
%       t         - [nSamples x 1] time vector in seconds (0-based).
%
%       bandInfo  - summary struct:
%                     .bandNames    — [nBands x 1] string
%                     .channelNames — [nChannels x 1] string
%                     .nChannels    — number of channels
%                     .nSamples     — samples per channel
%                     .nBands       — number of bands
%                     .sfreq        — sampling frequency
%
%   Pipeline:
%       % 1. Load saved CWT data
%       cwtMeta  = load(fullfile(outPath, "cwt", "provenance.mat"));
%       cwtStore = signalDatastore(fullfile(outPath, "cwt", "data"), ...
%           SampleRate=cwtMeta.provenance.sfreq);
%
%       % 2. Create Hilbert transform datastore
%       [hTds, hInfo] = hilbertTransform(cwtStore, ...
%           BandNames=cwtMeta.provenance.bandNames);
%
%       % 3. Read into per-band matrices
%       [amplitude, phase, t, bInfo] = readHilbertBands(hTds, hInfo);
%
%       % 4. Source-map a band (later)
%       % alphaSource = K * amplitude.alpha;  % [nSources x nSamples]
%
%   See also: hilbertTransform, applyHilbert, continuousWaveletTransform,
%             writeCWTDatastore

    arguments
        hTds        (1,1)
        hilbertInfo (1,1) struct
        opts.ChannelNames  = []
        opts.Verbose (1,1) logical = true
    end

    % ---- Extract info ----
    bandNames = hilbertInfo.bandNames(:);
    nBands    = hilbertInfo.nBands;
    ampCols   = hilbertInfo.amplitudeCols;
    phsCols   = hilbertInfo.phaseCols;
    sfreq     = hilbertInfo.sfreq;
    nSamples  = hilbertInfo.nSamples;

    % ---- Determine channel names ----
    if ~isempty(opts.ChannelNames)
        chanNames = string(opts.ChannelNames(:));
    else
        % Try to get from the underlying datastore
        try
            % TransformedDatastore wraps .UnderlyingDatastores{1}
            underDS = hTds.UnderlyingDatastores{1};
            chanNames = sdsGetChannelNames(underDS);
        catch
            chanNames = [];
        end
    end

    % ---- Read all channels ----
    reset(hTds);

    % Pre-allocate band matrices
    % First pass: count channels if unknown
    if isempty(chanNames)
        % Read all and count
        allData = {};
        ci = 0;
        while hasdata(hTds)
            ci = ci + 1;
            [hMat, ~] = read(hTds);
            allData{ci} = hMat; %#ok<AGROW>
        end
        nChannels = ci;
        chanNames = "ch" + (1:nChannels)';
    else
        nChannels = numel(chanNames);
        allData = cell(1, nChannels);

        for ci = 1:nChannels
            if ~hasdata(hTds)
                warning('readHilbertBands:Underflow', ...
                    'Datastore exhausted after %d channels (expected %d).', ...
                    ci-1, nChannels);
                nChannels = ci - 1;
                chanNames = chanNames(1:nChannels);
                allData = allData(1:nChannels);
                break;
            end
            [hMat, ~] = read(hTds);
            allData{ci} = hMat;

            if opts.Verbose && (ci <= 3 || ci == nChannels || mod(ci, 50) == 0)
                fprintf('readHilbertBands: channel %d/%d (%s)\n', ...
                    ci, nChannels, chanNames(ci));
            end
        end
    end
    reset(hTds);

    % ---- Pivot to per-band matrices [nChannels x nSamples] ----
    amplitude = struct();
    phase     = struct();

    for bi = 1:nBands
        bn = bandNames(bi);
        ampMat = zeros(nChannels, nSamples);
        phsMat = zeros(nChannels, nSamples);

        for ci = 1:nChannels
            hMat = allData{ci};
            ampMat(ci, :) = hMat(:, ampCols(bi))';
            phsMat(ci, :) = hMat(:, phsCols(bi))';
        end

        amplitude.(bn) = ampMat;
        phase.(bn)     = phsMat;
    end

    % ---- Time vector ----
    t = (0:nSamples-1)' / sfreq;

    % ---- Band info ----
    bandInfo = struct();
    bandInfo.bandNames    = bandNames;
    bandInfo.channelNames = chanNames;
    bandInfo.nChannels    = nChannels;
    bandInfo.nSamples     = nSamples;
    bandInfo.nBands       = nBands;
    bandInfo.sfreq        = sfreq;

    if opts.Verbose
        fprintf('readHilbertBands: complete\n');
        fprintf('  Channels: %d\n', nChannels);
        fprintf('  Samples:  %d (%.2f s at %.1f Hz)\n', nSamples, nSamples/sfreq, sfreq);
        fprintf('  Bands:    %d [%s]\n', nBands, strjoin(bandNames, ", "));
        for bi = 1:nBands
            fprintf('  amplitude.%-8s: [%d × %d]\n', ...
                bandNames(bi), nChannels, nSamples);
        end
    end
end
