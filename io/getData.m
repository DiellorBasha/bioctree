function data = getData(fileInt)
%GETDATA Summary of this function goes here
%   Detailed explanation goes here
addpath(genpath(pwd))
data.result=load('results_dSPM-unscaled_MEG_KERNEL_210314_2210.mat');
data.datafile=load(sprintf('data_block00%d.mat',fileInt));
data.chanfile=load("channel_ctf_acc1.mat");
data.chanflag=load("chan_flags_v1.mat");
data.anat=load('Subject_068_anat\tess_cortex_pial_low.mat');
megInd = find(strcmp({data.chanfile.Channel.Type}, 'MEG'));
flagInd = find(data.datafile.ChannelFlag==1);
chans=intersect(megInd, flagInd);
chans=data.result.GoodChannel;
data.fs=2400;
data.IK= data.result.ImagingKernel;
data.F=data.datafile.F;
data.F=data.F(chans,:);

data.sourceTS = data.IK * data.F;
data.time = data.datafile.Time;
data.chans=chans;

end

