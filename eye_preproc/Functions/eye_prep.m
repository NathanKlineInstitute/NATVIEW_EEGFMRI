%% Preprocess eyetracking data (interpolate blinks, median filter)
function eye_prep(options)

    %% Setup
    % List subjects and sessions
    [subs, sessions] = list_sub_ses(options.raw_dir);
    
    % Loop over all files
    for sub = 1:length(subs) 
        for ses = 1:length(sessions{sub})
    
            % List all .edf files
            options.et_dir = sprintf('%s/%s/%s/%s', options.raw_dir, subs(sub).name, sessions{sub}{ses}, options.eye_dir);
            et_files = dir(options.et_dir);
            et_files = et_files(cellfun(@(C) contains(C, sprintf('%s.json', options.eye_file_label)), {et_files.name})); 
    
            % Define the output directory
            sub_prep_dir = sprintf('%s/%s/%s/%s', options.preproc_dir, subs(sub).name, sessions{sub}{ses}, options.eye_dir);
            if exist(sub_prep_dir, 'dir') == 0, mkdir(sub_prep_dir), end
            
            for f = 1:length(et_files)
    
                % Define output file
                et_prep_file = sprintf('%s/%s', sub_prep_dir, et_files(f).name);
    
                if exist(et_prep_file, 'file') == 0

                    fprintf('Preprocessing %s ...\n', et_files(f).name)
    
                    %% Load from BIDS data
                    % Metadata
                    metadata = load_et_bids_metadata(options.et_dir, et_files(f).name);

                    % Data
                    et_data = load_et_bids_data(options.et_dir, strrep(et_files(f).name, '.json', '.tsv.gz'));

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
                    metadata.Columns = [metadata.Columns, 'Interpolated Samples'];

                    % Metadata
                    save_et_bids_metadata(metadata, sub_prep_dir, et_files(f).name)

                    % Data
                    save_et_bids_data(et_data, sub_prep_dir, strrep(et_files(f).name, '.json', '.tsv'))

                end
    
            end
            
        end   
    end

end