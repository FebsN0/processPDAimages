function ?=A5_frictionGlassCalc_method2(?)

% This function opens the AFM cropped data previously created to calculate the glass friction
% coefficient. This method is more accurated than the method 1.
%
% Author: Bratati Das, Zheng Jianlu
% University of Tokyo
% 
%
% Last update 2023/6/1


% Convert Selected_AFM_data -> AFM_cropped_channels
% AFM_cropped_channels data is different as follows:
%  - Cropped from Selected_AFM_data
%  - Data origin is right-bottom (Selected_AFM_data is top-left).
%
% You can use 'stop 115-less.mat' from here. 

% mask data
%AFM_H_NoBk

% lateral data 
% Trace

index_ch=find(strcmp({AFM_cropped_channels.Channel_name},'Lateral Deflection')==1);
POI_LDTrace =index_ch(1,find(ismember(find(strcmp({AFM_cropped_channels.Channel_name},'Lateral Deflection')==1),find(strcmp({AFM_cropped_channels.Trace_type},'Trace')==1))));
Lateral_Trace_img = AFM_cropped_channels(POI_LDTrace).Cropped_AFM_image;

% Retrace

index_ch=find(strcmp({AFM_cropped_channels.Channel_name},'Lateral Deflection')==1);
POI_LDReTrace =index_ch(1,find(ismember(find(strcmp({AFM_cropped_channels.Channel_name},'Lateral Deflection')==1),find(strcmp({AFM_cropped_channels.Trace_type},'ReTrace')==1))));
Lateral_ReTrace_img = AFM_cropped_channels(POI_LDReTrace).Cropped_AFM_image;

%% Calc Offset

Offset = (Lateral_Trace_img - Lateral_ReTrace_img).* (~AFM_height_IO) / 2; %%Jianlu the unit is Volt
%%Offset = (Lateral_Trace_img - Lateral_ReTrace_img)/ 2; %%Jianlu entire offset
Offset=Offset*DET_AFM.Alpha;%% Jianlu convertation into Netwon
% Jianlu 07122023, flip the metrix Offset to align with imagesc figure.
Offset_flipped=flipud(Offset) % Jianlu
figure; mesh(Offset_flipped) % Jianlu
%figure; mesh(Offset); title('Offset')
figure; imagesc(Offset); colorbar; title('Offset')

%% calc average

Ave = mean(Offset,1);

%% Vertical Deflection

% Trace

index_ch=find(strcmp({AFM_cropped_channels.Channel_name},'Vertical Deflection')==1);
POI_VDTrace =index_ch(1,find(ismember(find(strcmp({AFM_cropped_channels.Channel_name},'Vertical Deflection')==1),find(strcmp({AFM_cropped_channels.Trace_type},'Trace')==1))));

VD_Trace_img = AFM_cropped_channels(POI_VDTrace).Cropped_AFM_image;

% ReTrace

index_ch=find(strcmp({AFM_cropped_channels.Channel_name},'Vertical Deflection')==1);
POI_VDReTrace =index_ch(1,find(ismember(find(strcmp({AFM_cropped_channels.Channel_name},'Vertical Deflection')==1),find(strcmp({AFM_cropped_channels.Trace_type},'ReTrace')==1))));

VD_ReTrace_img = AFM_cropped_channels(POI_VDReTrace).Cropped_AFM_image;

%% Detect over the threshold 
Th = 0.4e-8;
Ave_VD_Trace = mean(VD_Trace_img,1);
Ave_VD_ReTrace = mean(VD_ReTrace_img,1);
Diff_VD = abs(Ave_VD_Trace - Ave_VD_ReTrace);
Idx = Diff_VD < Th;

%% making figure offset vs vd
New_Ave_Offset = Ave(Idx);
New_Ave_VD = (Ave_VD_Trace + Ave_VD_ReTrace) / 2.0;
New_Ave_VD = New_Ave_VD(Idx);

figure;
plot(New_Ave_VD, New_Ave_Offset, 'x');
xlabel('Set Point (N)');
ylabel('Delta Offset (N)');
xlim([0,max(New_Ave_VD) * 1.1]);
%ylim([0, max(New_Ave_Offset)* 1.1 ]);


%% Linear fitting
x = New_Ave_VD;
y = New_Ave_Offset;
p = polyfit(x, y, 1);
yfit = polyval(p, x);

hold on;
plot(x, yfit, 'r-.');

%eqn = string("Linear: y = " + p(1)) + "x + " + string(p(2));
%text(min(x), max(y), eqn, "HorizontalAlignment", "Left", "VerticalAlignment","top");
eqn = sprintf('Linear: y = %f x %+f', p(1), p(2));

title({'Delta Offset vs Set Point'; eqn});