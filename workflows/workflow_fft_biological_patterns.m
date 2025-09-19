pfish=imread("test-data\pufferfishdetail.jpg");
size(pfish)
imshow(pfish)

%%
%% Load & prep
Irgb = imread("test-data\pufferfishdetail.jpg");  % 300x300x3
Irgb = imread("test-data\zebradetail.jpg");  % 300x300x3

I = rgb2gray(Irgb);
I = im2double(I);
% crop
I = I(1:500,1:500);
% Optional: light detrend (remove large-scale shading)
I = I - imgaussfilt(I, 15);        % high-pass-ish
I = I / std(I(:));                 % normalize

% Window to reduce FFT edge artifacts
% Window to reduce FFT edge artifacts (gentler than Hann)
[Nx,Ny] = size(I);
taper = 0.2;                         % 0 = rectangular, 1 = Hann; try 0.1–0.3
wx = tukeywin(Nx, taper);
wy = tukeywin(Ny, taper);
W  = wx .* wy.';                     % outer product to 2D
Iw = I .* W;
imshow(Iw)
%% 2-D FFT power spectrum
F = fftshift(fft2(Iw));
P = abs(F).^2;                     % power spectrum
P = P / max(P(:));                 % scale for plotting

% Zero the DC neighborhood (optional) to better see ring
ctr = floor(size(P)/2)+1;
r0 = 3;
[xg,yg] = ndgrid(1:Nx,1:Ny);
P(((xg-ctr(1)).^2+(yg-ctr(2)).^2) <= r0^2) = 0;

% --- Physical sizes (mm) ---
Lx = 1; Ly = 1;               % 1 mm x 1 mm patch
[Nx,Ny] = size(I);            % 300 x 300 (grayscale)

% --- 2-D FFT power spectrum (already computed as P with fftshift) ---
% Frequency axes in cycles/mm (Nyquist = 1/(2*dx) = Nx/(2*Lx))
kx = (-floor(Nx/2):ceil(Nx/2)-1) / Lx;   % length Nx, cycles/mm
ky = (-floor(Ny/2):ceil(Ny/2)-1) / Ly;   % length Ny, cycles/mm

% --- Spatial axes in mm for the image ---
x_mm = linspace(0, Lx, Nx);   % 0..1 mm
y_mm = linspace(0, Ly, Ny);   % 0..1 mm

% --- Visualize image & spectrum with meaningful axes ---
figure('Color','w'); 
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
% Spatial image (in mm)
% Power spectrum (in cycles/mm)

imagesc(kx, ky, P.^0.4);      % gamma for visibility
set(gca,'YDir','normal'); colormap(gray);
xlabel('k_x (cycles/mm)'); ylabel('k_y (cycles/mm)');
title('Power spectrum (cycles/mm)');
colorbar;

%% Orientation analysis (find peaks on annulus)
% Pick radius band with strongest energy (coarse)
% 1) radial average to get dominant radius (spatial frequency)
%% --- Radial average to get dominant radius (spatial frequency) ---
[x0,y0] = deal(ctr(1), ctr(2));
rr = sqrt((xg-x0).^2 + (yg-y0).^2);

rmax  = floor(min(Nx,Ny)/2);
nbins = rmax;                            % 1 pixel per bin (tweak as needed)
edges = linspace(0, rmax, nbins+1);
rCenters = 0.5*(edges(1:end-1)+edges(2:end));

% Bin indices for each pixel (use discretize; clamp NaNs & right-edge)
binIdx = discretize(rr, edges);
binIdx(isnan(binIdx)) = 1;
binIdx(binIdx==numel(edges)) = numel(edges)-1;

% Radial mean power
radPow = accumarray(binIdx(:), P(:), [nbins 1], @mean, 0);

% Smooth & peak
radPowSm = smoothdata(radPow, 'gaussian', 7);
lo = 5;                                   % skip DC neighborhood
[~,rPeakBin] = max(radPowSm(lo:end));
rPeakBin = rPeakBin + lo - 1;
rPeak = rCenters(rPeakBin);


%% --- Angular power at the dominant radius (orientation) ---
band = abs(rr - rPeak) <= 2;              % thin annulus around rPeak
A = P; A(~band) = 0;

theta = atan2(yg-y0, xg-x0);              % [-pi, pi]
nth = 180;
edgesTh = linspace(-pi, pi, nth+1);

angIdx = discretize(theta, edgesTh);
angIdx(isnan(angIdx)) = 1;
angIdx(angIdx==numel(edgesTh)) = numel(edgesTh)-1;

angPow = accumarray(angIdx(:), A(:), [nth 1], @sum, 0);
angPowSm = smoothdata(angPow,'gaussian',5);

[~,k1] = max(angPowSm);
domTheta = 0.5*(edgesTh(k1)+edgesTh(k1+1));   % radians

% Report
k_cyc_per_image = rPeak;                   % cycles per image (square)
k_cyc_per_pixel = k_cyc_per_image / Nx;
lambda_pixels = 1 / k_cyc_per_pixel;

fprintf('Dominant wavelength ~ %.1f pixels\n', lambda_pixels);
fprintf('Dominant orientation (spectrum angle) ~ %.1f deg\n', rad2deg(domTheta));
fprintf('Image-pattern orientation ≈ %.1f deg\n', mod(rad2deg(domTheta)+90,180));


%% Plot radial/angle spectra
figure('Color','w'); 
subplot(1,2,1); plot(rCenters, radPowSm, 'LineWidth',1.5); grid on;
xlabel('Radius (freq pixels)'); ylabel('Power'); title('Radial power'); xlim([0 rmax]);
subplot(1,2,2); thdeg = linspace(-180,180,nth);
plot(thdeg, angPowSm, 'LineWidth',1.5); grid on;
xlabel('Angle (deg)'); ylabel('Power'); title('Angular power @ dominant radius'); xlim([-180 180]);

%% Helper: bin indexer for accumarray
function idx = binIdxFcn(vals, edges)
   [~,idx] = histc(vals, edges); 
   idx(idx==numel(edges)) = idx(idx==numel(edges))-1; % right-edge fix
   idx(idx==0) = 1;                                   % clamp
end
%
%% --- Params
vidPath = "test-data/reaction-diffusion-stim.mp4";
Fs      = 30;             % frame rate (Hz), from VideoReader
mmPerPx = [];             % set to e.g. 0.01 if you know scale (mm/pixel); [] keeps cycles/pixel
taper   = 0.2;            % Tukey window taper (0.1–0.3 is gentle)
maxFrames = inf;          % set < NumFrames to downsample in time if needed
spatialDecim = 1;         % set >1 to decimate spatially for speed (e.g., 2 or 3)

%% --- Load video to [Ny x Nx x T] (grayscale, single)
vr = VideoReader(vidPath);
T  = min(vr.NumFrames, maxFrames);
I0 = []; 
for t = 1:T
    f = read(vr, t);
    g = rgb2gray(f);
    if spatialDecim > 1
        g = imresize(g, 1/spatialDecim, "bilinear");
    end
    if t==1
        [Ny,Nx] = size(g);
        I0 = zeros(Ny,Nx,T, 'single');
    end
    I0(:,:,t) = im2single(g);
end
clear f g
%%
implay(I0)
%% --- Detrend: remove per-pixel mean (DC in time) and per-frame mean (global flicker)
I = I0 - mean(I0, 3);                  % remove time-mean at each pixel
frMean = squeeze(mean(mean(I,1),2));   % frame mean over space
I = I - reshape(frMean, [1 1 T]);      % remove frame-wise offset
I = I ./ max(std(reshape(I,[],T),0,2)+eps,[],'all');  % normalize (optional)
implay(I0)
%% --- Gentle apodization (space and time)
wx = tukeywin(Nx, taper);
wy = tukeywin(Ny, taper);
wt = tukeywin(T,  min(taper*2,0.6));   % slightly stronger taper in time
Wxy = wy * wx.';                       % outer product
W   = Wxy .* reshape(wt, 1,1,[]);
Iw  = I .* W;
implay(I0)
%% --- 3D FFT -> power spectrum P(kx, ky, f)
F = fftshift(fftn(Iw), [1 2 3]);
P = abs(F).^2;                         % power
P = P / max(P(:));                     % scale for display

%% --- Frequency axes
% Spatial cycles per pixel (Nyquist = 0.5 cyc/px)
kx = (-floor(Nx/2):ceil(Nx/2)-1) / Nx * 1;    % cyc/px
ky = (-floor(Ny/2):ceil(Ny/2)-1) / Ny * 1;    % cyc/px
% Temporal frequency (Hz)
f = (-floor(T/2):ceil(T/2)-1) / T * Fs;       % Hz

% If you know mmPerPx, convert to cycles/mm
if ~isempty(mmPerPx)
    kx = kx / mmPerPx;   % cyc/mm
    ky = ky / mmPerPx;   % cyc/mm
end

%% --- k–ω spectrum: radial average over spatial angles for each temporal freq
% Build grids for radius in spatial frequency domain
[kxg, kyg] = ndgrid(ky, kx);   % (Ny x Nx) note: rows->ky, cols->kx
kr = sqrt(kxg.^2 + kyg.^2);    % spatial frequency radius
% Binning radii
if isempty(mmPerPx)
    kUnit = 'cycles/pixel';
    kNyq  = 0.5;
else
    kUnit = 'cycles/mm';
    kNyq  = 0.5/mmPerPx;
end
nbins = round(min(Nx,Ny)/2);
kEdges = linspace(0, kNyq, nbins+1);
kCenters = 0.5*(kEdges(1:end-1)+kEdges(2:end));

% Allocate k–ω matrix (k radius x temporal freq)
KOmega = zeros(nbins, T, 'single');

% For each temporal frequency slice, radially average P(:,:,t)
for ti = 1:T
    Pslice = P(:,:,ti);
    % Bin indices for each pixel
    idx = discretize(kr, kEdges);
    % Radial mean at this temporal freq
    KOmega(:,ti) = accumarray(idx(:), Pslice(:), [nbins 1], @mean, 0);
end

% Shift temporal dimension to put DC in center already done by fftshift above
% Optional: keep only nonnegative temporal freqs for plots
posF = f >= 0;            % 0..Nyquist
KOm_pos = KOmega(:, posF);
f_pos   = f(posF);

%% --- Quick visualizations

% 1) One example frame & its spatial spectrum at a chosen freq bin
[~,tiMax] = max(sum(KOm_pos,1));  % temporal bin with most energy
PsliceShow = P(:,:, find(posF,1,'first')-1 + tiMax);

figure('Color','w'); tiledlayout(2,3,'TileSpacing','compact','Padding','compact');

nexttile; imagesc(I0(:,:,max(1,round(T/2)))); axis image off; colormap(gray);
title('Example frame');

nexttile; imagesc(kx, ky, PsliceShow.^0.3); axis image; set(gca,'YDir','normal');
colormap(gray); colorbar; xlabel(['k_x (' kUnit ')']); ylabel(['k_y (' kUnit ')']);
title(sprintf('Spatial spectrum @ f=%.2f Hz', f_pos(tiMax)));

% 2) k–ω (k radius vs temporal frequency)
nexttile([2 2]);
imagesc(f_pos, kCenters, (KOm_pos).^0.3); axis xy; colormap(parula); colorbar;
xlabel('Temporal frequency f (Hz)'); ylabel(['Spatial frequency k (' kUnit ')']);
title('k–\omega spectrum (radial spatial avg)');

% 3) Radial spatial spectrum at a few temporal slices
nexttile;
hold on;
for ff = linspace(0, max(f_pos), 4)
    [~,idxf] = min(abs(f_pos-ff));
    plot(kCenters, smoothdata(KOm_pos(:,idxf),'gaussian',5), 'DisplayName',sprintf('f=%.2f Hz', f_pos(idxf)));
end
grid on; xlabel(['k (' kUnit ')']); ylabel('Power'); legend show; title('Radial spectra @ selected f');

%% --- Estimate wave speed from the ridge (optional)
% For each f>0, find k at max power; fit v ~ f/k (pixels/s or mm/s)
k_at_max = zeros(1, numel(f_pos));
for j = 1:numel(f_pos)
    [~,imx] = max(KOm_pos(:,j));
    k_at_max(j) = kCenters(imx);
end
% Keep bins with clear nonzero k and f
sel = (f_pos > 0.5) & isfinite(k_at_max) & (k_at_max > 0);  % ignore near-DC
v_est = median(f_pos(sel) ./ k_at_max(sel));  % pixels/s if cycles/pixel, or mm/s if cycles/mm

fprintf('Estimated phase speed v ≈ %.2f %s/s (from ridge f/k)\n', ...
    v_est, isempty(mmPerPx)*"pixels"+(~isempty(mmPerPx))*"mm");
