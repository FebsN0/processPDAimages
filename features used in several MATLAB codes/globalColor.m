function col = globalColor(n)
    colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00','#0000FF','#FF0000'};
    % convert HEX into RGB for avoid issues in using HEX format
    hexColor=char(colors{n});
    rgbColor = sscanf(hexColor(2:end), '%2x%2x%2x', [1 3]) / 255;
    col=rgbColor;
end