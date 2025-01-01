%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% SAME FUNCTION FOR METHOD 1,2 and 3 but method 3 uses this function %%%
%%% many times depending on pix value                                  %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Input: x and y are the data to fit or the fitted curve in case of plot only.
%        idxFile is the idx of the i-th processed scan
% Output = fitting results. 
% FITTING VERTICAl and LATERAL DEFLECTION (both expressed in NanoNewton)
% The function also plot the fitted results of every methods for better comparison

% The function allow the fitting and/or plot each curve
% in case of method 2, fit and plot the relation of a given experiment.
% in case of method 3, avoid to plot every curve for each pixel ==> only fit, then, when all the pixels are
% done, plot the curve of the best choosen pixel only. Save significantly time
function [pfit,xData,yData]=feature_fittingForceSetpoint(x,y,idxFile,varargin)
    p=inputParser(); 
    argName = 'fitting';            defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'imageProcessing';    defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'fitResults';         defaultVal = [];        addParameter(p,argName,defaultVal)
    parse(p,varargin{:});
    % suppress the warning for the fitting
    id='curvefit:fit:iterationLimitReached';
    warning('off',id)
    if strcmpi(p.Results.fitting,'Yes'), fitting=true; else, fitting=false; end
    if strcmpi(p.Results.imageProcessing,'Yes'), imageProcessing=true; else, imageProcessing=false; end
    if ~(imageProcessing || fitting)
        error('Operation not allowed. At least one operation must be ''Yes''')
    end
    pfit=p.Results.fitResults;
        
    % Linear fitting
    if fitting
        % prepare the data
        [xData, yData] = prepareCurveData(x,y);
        % Set up fittype and options.
        ft = fittype( 'poly1' ); opts = fitoptions( 'Method', 'LinearLeastSquares'); opts.Robust = 'LAR';
        % Fit model to data.
        fitresult = fit( xData, yData, ft, opts);       
        x=xData;
        pfit(1)=fitresult.p1;
        pfit(2)=fitresult.p2;
    end
    
    if imageProcessing
        xfit=linspace(min(x),max(x),100);
        yfit=xfit*pfit(1)+pfit(2);
        if pfit(2) < 0
            signM='-';
        else
            signM='+';
        end
        plot(xfit, yfit, '-.','color',globalColor(idxFile),'DisplayName',sprintf('Fitted data: %0.3g x %s %0.3g',pfit(1),signM,abs(pfit(2))),'LineWidth',2);    
    end
end           

% pseudo global variable
function col = globalColor(n)
    colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00','#0000FF','#FF0000'};
    col=colors{n};
end