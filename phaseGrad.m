anat= load('/export01/data/brainstorm_db/PAD7JG/anat/Subject_068/tess_cortex_pial_low.mat');
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