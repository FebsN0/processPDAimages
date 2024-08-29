function A11_feature_fittingResults(dataX,dataY,secondMonitorMain,newFolder)
    
    hold on
    % Fit: 'untitled fit 1'.
    % A(A==AFM_cropped_channels_Big(POI_LD).Padded_masked(:))=NewValue;
    dataX(Dat>=1e-7) = NaN;
    dataX(dataX<0) = NaN;
    [xData, yData] = prepareCurveData(dataX, dataY);
    
    % Set up fittype and options.
    ft = fittype( 'poly1' );
    
    % Fit model to data.
    [fitresult, ~] = fit( xData, yData, ft );
    
    % Plot fit with data.
    figure( 'Name', 'fitting curve' );
    h = plot( fitresult, xData, yData );
    disp(fitresult);
    
    legend( h, 'FL vs. LD', 'fitting curve', 'Location', 'NorthEast', 'Interpreter', 'none' );
    % Label axes
    xlabel( 'LD', 'Interpreter', 'none' );
    ylabel( 'FL', 'Interpreter', 'none' );

end