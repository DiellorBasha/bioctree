function [dataOut, infoOut] = applyHilbert(dataIn, info, config)
%APPLYHILBERT Transform function for Hilbert amplitude & phase extraction.
%
%   [dataOut, infoOut] = applyHilbert(dataIn, info, config)
%
%   Designed for use with MATLAB's transform() on a signalDatastore
%   containing CWT band data ([nSamples x nBands] per channel).
%
%   Applies:
%       1. Scaling: dataIn * config.scaleFactor  (e.g. 1e12 for MEG→fT)
%       2. Hilbert transform per column (band)
%       3. Extracts amplitude (abs) and phase (angle)
%
%   Output is [nSamples x 2*nBands]:
%       columns  1:nBands         — amplitude envelope per band
%       columns  (nBands+1):end   — instantaneous phase per band (radians)
%
%   Inputs:
%       dataIn - [nSamples x nBands] CWT band matrix for one channel
%       info   - info struct from signalDatastore read()
%       config - struct with:
%                .scaleFactor - multiplicative scaling (default 1e12)
%                .bandNames   - [nBands x 1] string array (optional)
%
%   Outputs:
%       dataOut - [nSamples x 2*nBands] amplitude then phase columns
%       infoOut - info struct with added fields:
%                 .BandNames      - band names
%                 .AmplitudeCols  - column indices for amplitude
%                 .PhaseCols      - column indices for phase
%                 .ColumnNames    - [2*nBands x 1] string: "amp_delta",
%                                   "amp_theta", ..., "phase_delta", ...
%                 .ScaleFactor    - the scaling applied
%
%   See also: hilbertTransform, continuousWaveletTransform, writeCWTDatastore

    % Scale the input
    scaled = dataIn * config.scaleFactor;

    nBands = size(scaled, 2);

    % Hilbert transform (column-wise: each band independently)
    analytic = hilbert(scaled);

    % Extract amplitude and phase
    amp   = abs(analytic);
    phase = angle(analytic);

    % Pack into [N x 2*nBands]: amplitude first, then phase
    dataOut = [amp, phase];

    % Build column names
    if isfield(config, 'bandNames') && ~isempty(config.bandNames)
        bn = config.bandNames(:);
    else
        bn = "band" + (1:nBands)';
    end
    ampNames   = "amp_"   + bn;
    phaseNames = "phase_" + bn;

    % Augment info
    infoOut = info;
    infoOut.BandNames     = bn;
    infoOut.AmplitudeCols = 1:nBands;
    infoOut.PhaseCols     = (nBands+1):(2*nBands);
    infoOut.ColumnNames   = [ampNames; phaseNames];
    infoOut.ScaleFactor   = config.scaleFactor;
end
