function [dataOut, infoOut] = applyCWTBands(dataIn, info, config)
%APPLYCWTBANDS Transform function for CWT band decomposition.
%
%   [dataOut, infoOut] = applyCWTBands(dataIn, info, config)
%
%   Designed for use with MATLAB's transform() on a signalDatastore.
%   Computes CWT for a single channel and reconstructs time-domain signals
%   in each frequency band via icwt.
%
%   Inputs:
%       dataIn - [N x 1] or [1 x N] single-channel signal
%       info   - info struct from signalDatastore read()
%       config - struct with pre-built CWT configuration:
%                .fb            - cwtfilterbank object
%                .fVec          - [nScales x 1] frequency vector
%                .wavelet       - wavelet name string ("morse","amor","bump")
%                .nBands        - number of frequency bands
%                .bandNames     - [nBands x 1] string array of band names
%                .bandRanges    - struct with band frequency ranges
%                .clippedRanges - {nBands x 1} cell of clipped [fLow fHigh]
%                .bandValid     - [nBands x 1] logical
%
%   Outputs:
%       dataOut - [N x nBands] matrix of band reconstructions
%       infoOut - info struct with added .BandNames field
%
%   See also: cwtBandTransform, continuousWaveletTransform

    x = dataIn(:);
    N = numel(x);

    % Compute CWT
    [cfs, ~] = wt(config.fb, x);

    % Reconstruct each band
    dataOut = zeros(N, config.nBands);
    for bi = 1:config.nBands
        if config.bandValid(bi)
            xBand = icwt(cfs, config.wavelet, config.fVec, ...
                config.clippedRanges{bi}, 'SignalMean', 0);
            dataOut(:, bi) = xBand(:);
        end
    end

    % Augment info
    infoOut = info;
    infoOut.BandNames = config.bandNames;
    infoOut.BandRanges = config.bandRanges;
end
