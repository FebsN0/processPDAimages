%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% SAME FUNCTION FOR METHOD 1,2 and 3 but method 3 uses this function %%%
%%% many times depending on pix value                                  %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Output = fitting results. 
% FITTING VERTICAl and LATERAL DEFLECTION (both expressed in NanoNewton)
% The function also plot the fitted results of every methods for better comparison

function [p,xData]=feature_fittingForceSetpoint(x,y,varargin)
    % Linear fitting
    [xData, yData] = prepareCurveData(x,y');
    % Set up fittype and options.
    ft = fittype( 'poly1' ); opts = fitoptions( 'Method', 'LinearLeastSquares' ); opts.Robust = 'LAR';
    % Fit model to data.
    fitresult = fit( xData, yData, ft, opts );
    p(1)=fitresult.p1;
    p(2)=fitresult.p2;
    % in case of method 2, plot the relation of a given experiment.
    % in case of method 3, avoid to plot every curve
    if nargin == 3
        xfit=linspace(min(xData),max(xData),100);
        yfit=xfit*p(1)+p(2);
        if p(2) < 0
            signM='-';
        else
            signM='+';
        end
        plot(xfit, yfit, '-.','color',globalColor(varargin{1}),'DisplayName',sprintf('Fitted data: %0.3g x %s %0.3g',p(1),signM,abs(p(2))),'LineWidth',2);    
    end
end           

% pseudo global variable
function col = globalColor(n)
    colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00','#0000FF','#FF0000'};
    col=colors{n};
end