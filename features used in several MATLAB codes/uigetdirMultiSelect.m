function [files] = uigetdirMultiSelect(currPath,titleText)
    % custom function to multi select more directory
    % SOURCES:
    % 1) https://stackoverflow.com/questions/6349410/using-uigetfile-instead-of-uigetdir-to-get-directories-in-matlab
    % 2) https://www.mathworks.com/matlabcentral/fileexchange/32555-uigetfile_n_dir-select-multiple-files-and-directories

    if nargin < 1 || (isempty(currPath) & isempty(titleText))
        titleText = 'Select Directories'; % Titolo predefinito
        currPath=pwd;
    elseif isempty(currPath)
        currPath=pwd;
    elseif isempty(titleText)
        titleText='Select Directories';
    end
    
    % in case in future, problems will appear when com.mathworks will be no working anymore, uncomment the
    % following two lines and comment the other two similar lines
    % import javax.swing.JFileChooser;
    % jchooser = javaObjectEDT('javax.swing.JFileChooser', currPath);
    import com.mathworks.mwswing.MJFileChooserPerPlatform;
    jchooser = javaObjectEDT('com.mathworks.mwswing.MJFileChooserPerPlatform',currPath);

    jchooser.setFileSelectionMode(javax.swing.JFileChooser.DIRECTORIES_ONLY);
    jchooser.setMultiSelectionEnabled(true);
    jchooser.setDialogTitle(titleText);

    % Open the window with the custom text title
    jchooser.showOpenDialog([]);
    
    if jchooser.getState() == javax.swing.JFileChooser.APPROVE_OPTION
        jFiles = jchooser.getSelectedFiles();
        files = arrayfun(@(x) char(x.getPath()), jFiles, 'UniformOutput', false);
    elseif jchooser.getState() == javax.swing.JFileChooser.CANCEL_OPTION
        files = [];
    else
        error('Error occurred while picking file');
    end
end
