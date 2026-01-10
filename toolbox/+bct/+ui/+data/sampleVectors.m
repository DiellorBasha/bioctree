function [X, Y, Z, U, V, W] = sampleVectors(vectorData, vertices, options)
%BCT.UI.DATA.SAMPLEVECTORS  Convert vector field to quiver3 format with sampling
%
%   [X,Y,Z,U,V,W] = bct.ui.data.sampleVectors(vectorData, vertices)
%   [X,Y,Z,U,V,W] = bct.ui.data.sampleVectors(vectorData, vertices, Name, Value, ...)
%
% Purpose
%   Data adapter for vector field visualization.
%   Handles sampling, filtering, and format conversion for quiver3 display.
%
% Inputs
%   vectorData - [N×3] double: per-vertex vector field
%   vertices   - [N×3] double: mesh vertices
%
% Name-Value Arguments
%   SampleRate   - double [0,1], fraction of vectors to display (default: 0.1)
%   SampleMethod - "uniform" | "random" | "magnitude" (default: "uniform")
%   Scale        - double > 0, arrow length scale (default: 1.0)
%   MinMagnitude - double >= 0, threshold for display (default: 0)
%   Indices      - int array, explicit vertex indices to display
%
% Outputs
%   X,Y,Z - [M×1] double, arrow tail positions
%   U,V,W - [M×1] double, arrow direction vectors
%   where M = number of sampled vectors
%
% Sampling Methods
%   uniform   - Evenly spaced vertices
%   random    - Random subset
%   magnitude - Prefer high-magnitude vectors
%
% See also: quiver3

    arguments
        vectorData (:,3) double
        vertices (:,3) double
        options.SampleRate (1,1) double {mustBeInRange(options.SampleRate, 0, 1)} = 0.1
        options.SampleMethod (1,1) string {mustBeMember(options.SampleMethod, ["uniform", "random", "magnitude"])} = "uniform"
        options.Scale (1,1) double {mustBePositive} = 1.0
        options.MinMagnitude (1,1) double {mustBeNonnegative} = 0
        options.Indices (:,1) {mustBeInteger, mustBePositive} = []
    end
    
    nVerts = size(vertices, 1);
    
    if size(vectorData, 1) ~= nVerts
        error('bct:ui:data:SizeMismatch', ...
            'vectorData has %d rows but mesh has %d vertices', ...
            size(vectorData, 1), nVerts);
    end
    
    % Filter by magnitude threshold
    magnitudes = vecnorm(vectorData, 2, 2);
    validMask = magnitudes >= options.MinMagnitude & all(isfinite(vectorData), 2);
    
    if ~any(validMask)
        % No valid vectors
        X = zeros(0,1); Y = zeros(0,1); Z = zeros(0,1);
        U = zeros(0,1); V = zeros(0,1); W = zeros(0,1);
        return;
    end
    
    % Select indices based on method
    if ~isempty(options.Indices)
        % Explicit indices provided
        sampleIdx = options.Indices;
        sampleIdx = sampleIdx(sampleIdx >= 1 & sampleIdx <= nVerts);
        sampleIdx = intersect(sampleIdx, find(validMask));
    else
        validIndices = find(validMask);
        nSample = max(1, round(options.SampleRate * numel(validIndices)));
        
        switch options.SampleMethod
            case "uniform"
                % Evenly spaced
                step = max(1, floor(numel(validIndices) / nSample));
                sampleIdx = validIndices(1:step:end);
                
            case "random"
                % Random subset
                if nSample >= numel(validIndices)
                    sampleIdx = validIndices;
                else
                    perm = randperm(numel(validIndices), nSample);
                    sampleIdx = validIndices(perm);
                end
                
            case "magnitude"
                % Prefer high magnitude
                validMags = magnitudes(validIndices);
                [~, sortOrder] = sort(validMags, 'descend');
                sampleIdx = validIndices(sortOrder(1:min(nSample, end)));
        end
    end
    
    % Extract sampled data
    X = vertices(sampleIdx, 1);
    Y = vertices(sampleIdx, 2);
    Z = vertices(sampleIdx, 3);
    
    U = options.Scale * vectorData(sampleIdx, 1);
    V = options.Scale * vectorData(sampleIdx, 2);
    W = options.Scale * vectorData(sampleIdx, 3);
end
