%% Preprocess eyetracking data (interpolate blinks, median filter)
function eye_prep(et_prep_file, options)
    
    if exist(et_prep_file, 'file') == 0
    
        fprintf('Preprocessing %s ...\n', et_prep_file)
    
        % Get the file_parts
        [prep_dir, et_file] = fileparts(et_prep_file);

        %% Load from BIDS data
        % Metadata
        metadata = load_et_bids_metadata(options.et_dir, strrep(et_file, '.tsv', '.json'));
    
        % Data
        et_data = load_et_bids_data(options.et_dir, sprintf('%s.gz', et_file));
    
        % Blink data
        [labeled_events] = bwlabel(table2array(et_data(:, ismember(metadata.Columns, 'Blinks'))));
        props = regionprops(labeled_events, 'Area', 'PixelList');
    
        blink_onset = cellfun(@(C) min(C(:,2)), {props.PixelList});
        blink_offset = cellfun(@(C) max(C(:,2)), {props.PixelList});
    
        % Start and end sample needed 
        blinks = [blink_onset', blink_offset'];
    
        %% Preprocess
        et_data = preprocess_eyelink_data(et_data, options, metadata, blinks);
    
        %% Save the eyetracking data
        % Edit metadata
        metadata.Columns = [metadata.Columns, 'Interpolated_Samples'];
    
        % Add description of the column
        metadata.Interpolated_Samples.Description = sprintf('1 indicates interpolated samples based on blinks detected by eyelink; includes %i ms before and after blinks', options.buffer_ms);
    
        % Metadata
        save_et_bids_metadata(metadata, prep_dir, strrep(et_file, '.tsv', '.json'))
    
        % Data
        save_et_bids_data(et_data, prep_dir, et_file)
    
    end

end