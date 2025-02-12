function varargout = A7_feature_manualAlignment(fixed, moving)
    % Crea la finestra principale
    hFig = figure('Name', 'Manual Image Translation', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 900, 700], 'CloseRequestFcn', @on_close);

    % Variabili per la traslazione
    step = 1; % Default
    offset_x = 0;
    offset_y = 0;
    zoom_factor = 1.2; % Zoom increment
    original_moving = moving;  % Per il reset

    % Asse dell'immagine
    hAx = axes('Parent', hFig, 'Units', 'normalized', 'Position', [0.05, 0.2, 0.9, 0.75]);
    imshowpair(fixed, moving, 'falsecolor', 'Parent', hAx);
    
    % Controlli UI
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', '←', ...
              'Units', 'normalized', 'Position', [0.2, 0.05, 0.1, 0.05], ...
              'Callback', @(src, event) apply_translation('left'));

    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', '→', ...
              'Units', 'normalized', 'Position', [0.4, 0.05, 0.1, 0.05], ...
              'Callback', @(src, event) apply_translation('right'));

    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', '↑', ...
              'Units', 'normalized', 'Position', [0.3, 0.1, 0.1, 0.05], ...
              'Callback', @(src, event) apply_translation('down'));

    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', '↓', ...
              'Units', 'normalized', 'Position', [0.3, 0.05, 0.1, 0.05], ...
              'Callback', @(src, event) apply_translation('up'));

    % Casella di testo per il valore di step
    hStepEdit = uicontrol('Parent', hFig, 'Style', 'edit', 'String', '1', ...
                          'Units', 'normalized', 'Position',[0.55, 0.05, 0.1, 0.05]);

    % Zoom in e out
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', '+', ...
              'Units', 'normalized', 'Position', [0.7, 0.1, 0.1, 0.05], ...
              'Callback', @(~,~) zoom_image(1/zoom_factor));

    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', '-', ...
              'Units', 'normalized', 'Position', [0.7, 0.05, 0.1, 0.05], ...
              'Callback', @(~,~) zoom_image(zoom_factor));

    % Pulsante RESET
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Reset', ...
              'Units', 'normalized', 'Position', [0.85, 0.05, 0.1, 0.05], ...
              'Callback', @(~,~) reset_translation());

    % Pulsante TERMINA
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Termina', ...
              'Units', 'normalized', 'Position', [0.85, 0.1, 0.1, 0.05], ...
              'Callback', @(~,~) close(hFig));

    % Movimento iterativo senza resettare la vista
    function apply_translation(direction)
        step = str2double(get(hStepEdit, 'String'));
        switch direction
            case 'up'
                offset_y = offset_y + step;
            case 'down'
                offset_y = offset_y - step;
            case 'right'
                offset_x = offset_x + step;
            case 'left'
                offset_x = offset_x - step;
        end
        moving = imtranslate(original_moving, [offset_x, offset_y], 'FillValues', 0);
        update_display();
    end

    % Zoom controllato
    function zoom_image(factor)
        xlims = xlim(hAx);
        ylims = ylim(hAx);
        center_x = mean(xlims);
        center_y = mean(ylims);
        range_x = diff(xlims) / 2 * factor;
        range_y = diff(ylims) / 2 * factor;
        xlim([center_x - range_x, center_x + range_x]);
        ylim([center_y - range_y, center_y + range_y]);
    end  

    % Funzione RESET
    function reset_translation()
        offset_x = 0;
        offset_y = 0;
        moving = original_moving;  % Ripristina immagine originale
        update_display();
    end

    % Funzione per aggiornare la visualizzazione senza resettare zoom e pan
    function update_display()
        old_xlim = xlim(hAx);
        old_ylim = ylim(hAx);
        imshowpair(fixed, moving, 'falsecolor', 'Parent', hAx);
        xlim(old_xlim); % Mantiene il livello di zoom attuale
        ylim(old_ylim);
        drawnow;
    end

    % Output finale solo con offset_x e offset_y
    function on_close(~, ~)
        assignin('base', 'offset_x', offset_x);
        assignin('base', 'offset_y', offset_y);
        delete(hFig);
    end


    uiwait(msgbox('Click ''OK'' to continue when the manual method is terminated',''));
    varargout{1}=offset_x;
    varargout{2}=offset_y;
end
