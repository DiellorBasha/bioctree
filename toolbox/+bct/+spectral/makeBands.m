function bands = makeBands(eigen, specs)
%MAKEBANDS Create band specifications from eigenvalue or eigenmode ranges
%
%   bands = bct.spectral.makeBands(eigen, specs)
%
% Purpose
%   Helper to create band structures for generateBandedSignal. Can specify
%   bands using either eigenmode indices OR eigenvalue ranges (spatial scales).
%
% Inputs
%   eigen - Eigenmode structure from M.eigenmodes()
%   specs - Struct array with fields:
%           Option 1 (by eigenmode index):
%             .eigenmodeRange - [kmin, kmax]
%           Option 2 (by eigenvalue - spatial scale):
%             .eigenvalueRange - [lambdaMin, lambdaMax]
%           
%           Required for all:
%             .freqRange      - [fmin, fmax] temporal frequency (Hz)
%             .amplitude      - Overall amplitude
%
% Output
%   bands - Struct array ready for bct.spectral.generateBandedSignal
%           with .eigenmodeRange, .freqRange, .amplitude fields
%
% Examples
%   % Method 1: By eigenmode indices
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   eigen = M.eigenmodes(1000);
%   
%   specs(1).eigenmodeRange = [1, 100];
%   specs(1).freqRange = [8, 12];
%   specs(1).amplitude = 1.0;
%   
%   bands = bct.spectral.makeBands(eigen, specs);
%
%   % Method 2: By eigenvalue ranges (spatial scales)
%   specs(1).eigenvalueRange = [0, 0.01];     % Large spatial scales
%   specs(1).freqRange = [8, 12];              % Alpha
%   specs(1).amplitude = 1.0;
%   
%   specs(2).eigenvalueRange = [0.01, 0.05];  % Mid scales
%   specs(2).freqRange = [15, 30];             % Beta
%   specs(2).amplitude = 0.7;
%   
%   bands = bct.spectral.makeBands(eigen, specs);
%   
%   % Then generate signal
%   fs = 100; T = 10;
%   t = (0:1/fs:T-1/fs)';
%   X = bct.spectral.generateBandedSignal(M, bands, t);
%
% See also: bct.spectral.generateBandedSignal, bct.Manifold.eigenmodes

arguments
    eigen struct
    specs struct
end

%% Validate Inputs

% Check eigen structure
if ~isfield(eigen, 'eigenvalues') || ~isfield(eigen, 'eigenvectors')
    error('bct:spectral:InvalidEigen', ...
        'Input must be eigenmode structure from M.eigenmodes()');
end

lambda = eigen.eigenvalues.value;  % [K×1] eigenvalues
K = length(lambda);

%% Process Each Specification

bands = struct([]);

for i = 1:length(specs)
    spec = specs(i);
    
    % Determine eigenmode range
    if isfield(spec, 'eigenvalueRange')
        % Convert eigenvalue range to eigenmode indices
        lambdaRange = spec.eigenvalueRange;
        
        % Find eigenmodes within this eigenvalue range
        mask = lambda >= lambdaRange(1) & lambda <= lambdaRange(2);
        indices = find(mask);
        
        if isempty(indices)
            warning('bct:spectral:EmptyRange', ...
                'Band %d: No eigenmodes found in eigenvalue range [%.6f, %.6f]', ...
                i, lambdaRange(1), lambdaRange(2));
            continue;
        end
        
        eigenmodeRange = [min(indices), max(indices)];
        
    elseif isfield(spec, 'eigenmodeRange')
        % Use provided eigenmode range
        eigenmodeRange = spec.eigenmodeRange;
        
        % Validate range
        if eigenmodeRange(2) > K
            warning('bct:spectral:RangeExceeded', ...
                'Band %d: Eigenmode range [%d, %d] exceeds available modes (%d), truncating', ...
                i, eigenmodeRange(1), eigenmodeRange(2), K);
            eigenmodeRange(2) = K;
        end
        
    else
        error('bct:spectral:MissingRange', ...
            'Band %d must specify either eigenmodeRange or eigenvalueRange', i);
    end
    
    % Check required fields
    if ~isfield(spec, 'freqRange')
        error('bct:spectral:MissingFreqRange', ...
            'Band %d missing freqRange field', i);
    end
    
    if ~isfield(spec, 'amplitude')
        error('bct:spectral:MissingAmplitude', ...
            'Band %d missing amplitude field', i);
    end
    
    % Create band structure
    bands(i).eigenmodeRange = eigenmodeRange;
    bands(i).freqRange = spec.freqRange;
    bands(i).amplitude = spec.amplitude;
end

%% Summary

if nargout == 0 || true
    fprintf('Created %d band(s):\n', length(bands));
    fprintf('  Band | Eigenmode Range | Eigenvalue Range   | Freq Range (Hz)\n');
    fprintf('  -----+-----------------+--------------------+----------------\n');
    
    for i = 1:length(bands)
        eig_r = bands(i).eigenmodeRange;
        lambda_r = [lambda(eig_r(1)), lambda(eig_r(2))];
        freq_r = bands(i).freqRange;
        
        fprintf('  %4d | [%4d, %4d]    | [%6.4f, %6.4f] | [%4.0f, %4.0f]\n', ...
            i, eig_r(1), eig_r(2), lambda_r(1), lambda_r(2), ...
            freq_r(1), freq_r(2));
    end
end

end
