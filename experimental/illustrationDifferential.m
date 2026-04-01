x = linspace(0,1,1000);

Pos = [1 2 3 5 7 8]/10;
Hgt = [4 4 2 2 2 3];
Wdt = [3 8 4 3 4 6]/100;

for n = 1:length(Pos)
    Gauss(n,:) =  Hgt(n)*exp(-((x - Pos(n))/Wdt(n)).^2);
end

PeakSig = sum(Gauss);
%%
figure (1)
clf
nexttile
plot(PeakSig, 'b.')
nexttile
plot(diff(PeakSig), 'b.')
nexttile
plot(diff(diff(PeakSig)), 'b.')