function beautifyBoxPlot(f1,ax,dim)

grid off;
if exist('dim')
    ax.Units = 'inches';
    f1.Units = 'inches';
    goodPlotWhite2(f1, ax,dim);  
    f1.Position = 1.2 .* ax.OuterPosition;
    x_center = (f1.Position(3) - ax.Position(3)) / 2;
    y_center = (f1.Position(4) - ax.Position(4)) / 2;  
    ax.Position = [x_center y_center dim(1) dim(2)];
else
    goodPlotWhite2(f1,ax);
end
aa = allchild(ax);
bb = allchild(aa);
for ii = 1:length(aa); if isequal(aa(ii).Tag,'boxplot'); bb = allchild(aa(ii)); end; end;
for ii = 1:length(bb); bb(ii).Color = 'k'; end
for ii = 1:length(bb); bb(ii).LineWidth = 1; end

end


