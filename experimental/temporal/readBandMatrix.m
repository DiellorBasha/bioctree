function [mat, chanNames, sfreq] = readBandMatrix(sds)
%READBANDMATRIX Read a band signalDatastore into a [nChannels x nSamples] matrix.
%
%   [mat, chanNames, sfreq] = readBandMatrix(sds)
%
%   Reads all channels from a file-based signalDatastore (e.g. one band
%   folder written by writeHilbertBands) and assembles them into a matrix
%   suitable for source mapping: K * mat = [nSources x nSamples].
%
%   Each channel file contains a [nSamples x 1] column vector. This
%   function reads all channels and stacks them as rows.
%
%   Input:
%       sds - signalDatastore pointing at a band folder, e.g.:
%             signalDatastore("hilbert/amplitude/alpha", SampleRate=600)
%
%   Outputs:
%       mat       - [nChannels x nSamples] double matrix
%       chanNames - [nChannels x 1] string array of channel names
%                   (from filenames or MemberNames)
%       sfreq     - sampling frequency from sds.SampleRate
%
%   Examples:
%       % Load one band for source mapping:
%       hMeta = load(fullfile(outPath, "hilbert", "provenance.mat"));
%       sds_alpha = signalDatastore( ...
%           fullfile(outPath, "hilbert", "amplitude", "alpha"), ...
%           SampleRate=hMeta.provenance.sfreq);
%       mat = readBandMatrix(sds_alpha);     % [270 x 180001]
%       K = load(fullfile(outPath, "ImagingKernel.mat")).K;
%       alphaSource = K * mat;               % [10244 x 180001]
%
%       % Load all bands:
%       for bi = 1:numel(hMeta.provenance.bandNames)
%           bn = hMeta.provenance.bandNames(bi);
%           sds_b = signalDatastore( ...
%               fullfile(outPath, "hilbert", "amplitude", bn), ...
%               SampleRate=hMeta.provenance.sfreq);
%           sourceB.(bn) = K * readBandMatrix(sds_b);
%       end
%
%   See also: writeHilbertBands, readHilbertBands, sdsGetChannelNames

    chanNames = sdsGetChannelNames(sds);
    nChannels = numel(chanNames);
    sfreq     = sds.SampleRate;

    % Read first channel to get sample count
    reset(sds);
    x1 = read(sds);
    if iscell(x1), x1 = x1{1}; end
    nSamples = numel(x1);

    % Pre-allocate and fill
    mat = zeros(nChannels, nSamples);
    mat(1, :) = x1(:)';

    for ci = 2:nChannels
        x = read(sds);
        if iscell(x), x = x{1}; end
        mat(ci, :) = x(:)';
    end
    reset(sds);
end
