function rec = read_bs_block(fn, opts)
%READ_BS_BLOCK  Lightweight reader for Brainstorm data_block*.mat
%   rec = read_bs_block(fn, opts)
%
% Returns:
%   rec.X           [nChan x nTime] numeric (default single)
%   rec.Time        [1 x nTime] double
%   rec.Fs          scalar sampling rate (Hz)
%   rec.ChannelFlag [nChan x 1] double (if present)
%   rec.Comment     char (if present)
%   rec.DataType    char (if present)
%   rec.Device      char (if present)
%   rec.Events      struct array (if present)
%   rec.File        char (absolute file path)
%
% opts (all optional):
%   .channels   row vector of channel indices to read (default = all)
%   .cast       'single' (default) or 'double'
%   .useMatfile true (default) to avoid loading unused vars
%
% Notes:
% - Uses matfile for memory efficiency; falls back to load() if needed.
% - Fs is computed from median(diff(Time)) for robustness.
%
% Example:
%   rec = read_bs_block('/path/data_block001.mat', struct('channels',1:128,'cast','single'));

if nargin < 2 || isempty(opts), opts = struct; end
if ~isfield(opts,'channels'),  opts.channels  = [];      end
if ~isfield(opts,'cast'),      opts.cast      = 'single';end
if ~isfield(opts,'useMatfile'),opts.useMatfile= true;    end

% Normalize path
fn = char(string(fn));   % ensure char
rec = struct('X',[],'Time',[],'Fs',[],'ChannelFlag',[],'Comment','','DataType','', ...
             'Device','', 'Events',[], 'File', fn);

% Reader backend
useMF = false;
if opts.useMatfile
    try
        m = matfile(fn);
        useMF = true;
    catch
        useMF = false;
    end
end

% Helper to fetch a variable (with matfile or load)
getvar = @(name) fetchVar(name, useMF, fn, exist('m','var') && isa(m,'matlab.io.MatFile') && isprop(m,name), m);

% ---- Time ----
rec.Time = getvar('Time');
if isempty(rec.Time)
    error('read_bs_block:MissingTime','Variable "Time" not found in %s', fn);
end
dt  = median(diff(rec.Time));
rec.Fs = 1/dt;

% ---- Channels / F ----
% If channels not specified, we’ll read all rows.
Fsize = [];
if useMF
    % matfile supports size queries without loading
    try
        Fsize = size(m,'F');
    catch
        % fall back later
    end
end

if isempty(Fsize)
    % Peek via load to get size, then index again if needed
    S = whos('-file', fn, 'F');
    if isempty(S)
        error('read_bs_block:MissingF','Variable "F" not found in %s', fn);
    end
    Fsize = S.size;  % [nChan nTime]
end
nChan = Fsize(1);

if isempty(opts.channels)
    chIdx = 1:nChan;
else
    chIdx = opts.channels;
end

% Pull F rows we need
if useMF
    rec.X = m.F(chIdx, :);
else
    S = load(fn, 'F');
    rec.X = S.F(chIdx, :);
end

% Cast
switch lower(opts.cast)
    case 'single', rec.X = single(rec.X);
    case 'double', rec.X = double(rec.X);
    otherwise, error('read_bs_block:BadCast','opts.cast must be "single" or "double".');
end

% ---- Optional fields ----
rec.ChannelFlag = getvar('ChannelFlag');   % may be []
rec.Comment     = toChar(getvar('Comment'));
rec.DataType    = toChar(getvar('DataType'));
rec.Device      = toChar(getvar('Device'));
rec.Events      = getvar('Events');

end  % function

% ------- helpers -------
function v = toChar(v)
if isempty(v), v = ''; return; end
if isstring(v), v = char(v); end
if isnumeric(v) || iscell(v), v = char(string(v)); end
end

function v = fetchVar(name, useMF, fn, hasProp, m)
v = [];
if useMF && hasProp
    try
        v = m.(name);
        return
    catch
        % fall through to load
    end
end
try
    S = load(fn, name);
    if isfield(S, name), v = S.(name); end
catch
    % leave empty
end
end
