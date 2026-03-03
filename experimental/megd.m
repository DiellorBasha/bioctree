block(1).data=load("Z:\PADJG_GSP\data\sub-MTL0010\PADMTL0010PREMG00_spontaneous_20180712_01_notch_high\data_block001.mat");
block(2).data=load("Z:\PADJG_GSP\data\sub-MTL0010\PADMTL0010PREMG00_spontaneous_20180712_01_notch_high\data_block002.mat");
block(3).data=load("Z:\PADJG_GSP\data\sub-MTL0010\PADMTL0010PREMG00_spontaneous_20180712_01_notch_high\data_block002.mat");
block(4).data=load("Z:\PADJG_GSP\data\sub-MTL0010\PADMTL0010PREMG00_spontaneous_20180712_01_notch_high\data_block002.mat");
block(5).data=load("Z:\PADJG_GSP\data\sub-MTL0010\PADMTL0010PREMG00_spontaneous_20180712_01_notch_high\data_block002.mat");

block(1).data
recs=[block(1).data.F ,block(2).data.F,block(3).data.F,block(4).data.F,block(5).data.F ];
for k = 1:size(recs,1)
recsds(k,:)=zscore(downsample(recs(k,:), 4), 0, 2);
end
%%
cla
for k=105:225
    hold on
plot(recsds(k,:)+2*k, 'k')
hold off
end

%%
zscrec=zscore(recs,0,2);
cla

for k=85:105
    hold on
plot(zscore(recs (k,:)+2*k), 'k')
hold off
end

%%

block(67).data=load("Z:\PADJG_GSP\data\sub-MTL0005\PADMTL0005NAPMG00_spontaneous_20170714_01_notch_high\data_block067.mat");
block(68).data=load("Z:\PADJG_GSP\data\sub-MTL0005\PADMTL0005NAPMG00_spontaneous_20170714_01_notch_high\data_block068.mat");
block(69).data=load("Z:\PADJG_GSP\data\sub-MTL0005\PADMTL0005NAPMG00_spontaneous_20170714_01_notch_high\data_block069.mat");
recs=[block(67).data.F ,block(68).data.F,block(69).data.F ];

%% 

zscrec=zscore(recs,0,2);
cla
for k=200:250
    hold on
plot(zscrec(k,:)+2*k, 'k')
hold off
end
