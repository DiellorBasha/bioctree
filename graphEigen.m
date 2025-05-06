anat=load('Subject_068_anat\tess_cortex_pial_low.mat');
V=anat.Vertices;
W=anat.VertConn;
F=anat.Faces;
result=load('results_dSPM-unscaled_MEG_KERNEL_210314_2210.mat');
datafile=load('data_block002.mat');
chanfile=load("channel_ctf_acc1.mat");
chanflag=load("chan_flags_v1.mat");
anat=load('Subject_068_anat\tess_cortex_pial_low.mat');
megInd = find(strcmp({chanfile.Channel.Type}, 'MEG'));
flagInd = find(datafile.ChannelFlag==1);
chans=intersect(megInd, flagInd);
fs=2400;
IK= result.ImagingKernel;
F=datafile.F;
F=F(chans,:);

S = IK * F;
time = datafile.Time;
%%
% Graph Laplacian
d = sum(W, 2);         % Degree for each vertex
D = spdiags(d, 0, size(W,1), size(W,2));  % Sparse diagonal matrix
L = D - W;             % Unnormalized Laplacian
% Unnormalized
D_inv_sqrt = spdiags(1./sqrt(d), 0, size(W,1), size(W,2));
L_norm = speye(size(W,1)) - D_inv_sqrt * W * D_inv_sqrt;

%% Eigenvectors
k = 100;  % Number of eigenvectors
opts.isreal = 1;
opts.issym = 1;
[U, lambda] = eigs(L, k, 'SM', opts);  % 'SM' = smallest magnitude eigenvalues
%%
for i = 5
    figure;
    patch('Faces', F, 'Vertices', V, ...
          'FaceVertexCData', U(:,i), 'FaceColor', 'interp', ...
          'EdgeColor', 'none');
    axis equal off;
    title(['Eigenvector ', num2str(i), ', Eigenvalue = ', num2str(lambda(i,i))]);
    colorbar;
end

%%

% Example: low-pass filter g(lambda) = exp(-tau*lambda)
tau = 0.1;
g = exp(-tau * diag(lambda));

% Apply to a signal f (e.g., delta at a vertex)
v_idx = 1000;
f = zeros(size(V,1), 1); f(v_idx) = 1;

f_hat = U' * f;         % Graph Fourier Transform
f_filtered = U * (g .* f_hat);  % Inverse Graph Fourier Transform

% Visualize result
figure;
patch('Faces', F, 'Vertices', V, ...
      'FaceVertexCData', f_filtered, 'FaceColor', 'interp', ...
      'EdgeColor', 'none');
axis equal off;
title(['Wavelet response at vertex ', num2str(v_idx)]);
colorbar;
%% 
fs = 2400;  % Sampling frequency in Hz (adjust if different)
signalLength = size(S, 2);
numVertices = size(S, 1);

fb = cwtfilterbank('SignalLength', signalLength, ...
                   'SamplingFrequency', fs, ...
                   'VoicesPerOctave', 12, ...
                   'FrequencyLimits', [1 fs/2]);  % adjust for your band of interest

[~, freq]=cwt(S(1,:), FilterBank=fb);
numFreqs = numel(freq);

% You may store summary results, like max power per vertex/frequency
maxPower = zeros(numVertices, numFreqs, 'single');


% Loop through in blocks of 50 vertices
for startIdx = 1:blockSize:numVertices
    endIdx = min(startIdx + blockSize - 1, numVertices);
    blockRange = startIdx:endIdx;

    fprintf('Processing vertices %d to %d...\n', startIdx, endIdx);
    
    for i = 1:numel(blockRange)
        v = blockRange(i);

[wt_v, ~] = cwt(S(v,:), FilterBank=fb);  % wt_v: [numFreqs x signalLength]
power_v = abs(wt_v).^2;

        % OPTIONAL: Store to disk or analyze on-the-fly here if needed
    end
end
%% 
