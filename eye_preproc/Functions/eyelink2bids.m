%% Convert eyelink data to bids format 

function eyelink2bids(options)
    
    %% Setup
    % List subjects and sessions
    [subs, sessions] = list_sub_ses(options.raw_dir);
    
    % Array to collect missing files
    missing_eeg = {};
    
    % Initialize arrays for quality control metrics
    eeg_et_sample_diff = [];
    percent_missing_samples = [];
    percent_out_samples = [];
    file_names = {};
    
    % QC files
    eeg_et_sample_diff_file = sprintf('%s/eeg_et_sample_diff.mat', options.res_dir);
    percent_missing_samples_file = sprintf('%s/percent_missing_samples.mat', options.res_dir);
    percent_out_samples_file = sprintf('%s/percent_out_samples.mat', options.res_dir);
    missing_eeg_file = sprintf('%s/missing_eeg.mat', options.res_dir);
    
    %% Convert all files to BIDS format
    for sub = 1:length(subs)
        for ses = 1:length(sessions{sub})
    
            % List all .edf files
            options.et_dir = sprintf('%s/%s/%s/%s', options.raw_dir, subs(sub).name, sessions{sub}{ses}, options.eye_dir);
            et_files = dir(options.et_dir);
            et_files = et_files(cellfun(@(C) contains(C, '.edf'), {et_files.name})); 
    
            for f = 1:length(et_files)
    
                % Define csv file for event data (last file created)
                data_file = sprintf('%s/%s', options.et_dir, strrep(et_files(f).name, '_eyelink.edf', sprintf('%s.tsv.gz', options.eye_file_label)));
    
                % Skip recording if the csv file already exists
                if exist(strrep(data_file, '.csv', '.tsv'), 'file') ~= 0, continue, end
                
                % Load quality control files if they exist
                if exist(eeg_et_sample_diff_file, 'file') ~= 0, load(eeg_et_sample_diff_file, 'eeg_et_sample_diff'); end
                if exist(percent_missing_samples_file, 'file') ~= 0, load(percent_missing_samples_file, 'percent_missing_samples'); end
                if exist(percent_out_samples_file, 'file') ~= 0, load(percent_out_samples_file, 'percent_out_samples', 'file_names'); end
                if exist(missing_eeg_file, 'file') ~= 0, load(missing_eeg_file, 'missing_eeg'); end
    
                %% Convert .edf files to .asc
                edf_file = sprintf('%s/%s', options.et_dir, et_files(f).name);
                asc_file = strrep(edf_file, '.edf', '.asc');
    
                if exist(asc_file, 'file') == 0
                    system(sprintf('edf2asc -y -res %s', edf_file));
                end
    
                %% Load the EEG data
                eeg_dir = sprintf('%s/%s/%s/%s', options.preproc_dir, subs(sub).name, sessions{sub}{ses}, options.eeg_dir);
                eeg_file = strrep(et_files(f).name, '_eyelink.edf', '_eeg.set');
    
                try
                    EEG = pop_loadset(eeg_file, eeg_dir);
                catch
                    missing_eeg = [missing_eeg; et_files(f).name];
                    save(missing_eeg_file, 'missing_eeg');
                    continue
                end
    
                % Reconstruct time axis
                EEG.times = 0:1/EEG.srate:(length(EEG.etc.clean_sample_mask)-1)/EEG.srate;
    
                %% PEER data is missing triggers (skip)
                if contains(et_files(f).name, 'PEER', 'IgnoreCase', true) 
                    continue
                end
    
                %% Load trigger information
                trigger_table = readtable('trigger_ids.xlsx');
                
                trigger_table = trigger_table(cellfun(@(C) contains(et_files(f).name, C, 'IgnoreCase', true), trigger_table.bids_name), :);
        
                idx_eeg = cellfun(@(C) contains('eeg', C), trigger_table.data_type); 
    
                %% EEG triggers 
                eeg_trg_samples = round([EEG.urevent.latency]);
                eeg_trg_id = {EEG.urevent.type};
        
                eeg_trg_on = eeg_trg_samples(ismember(eeg_trg_id, trigger_table.task_start{idx_eeg}));
                eeg_trg_off = eeg_trg_samples(ismember(eeg_trg_id, trigger_table.task_end{idx_eeg}));
                
                eeg_trg_timer = eeg_trg_samples(ismember(eeg_trg_id, trigger_table.timer_1{idx_eeg}));

                eeg_trg_fmri = eeg_trg_samples(ismember(eeg_trg_id, 'R128'));

                %% Load ET data
                [et_data, metadata, et_events, et_trgs] = load_asc(options.et_dir, strrep(et_files(f).name, '.edf', '.asc'), trigger_table, EEG.times(eeg_trg_on));
    
                %% Interpolate fMRI triggers from EEG data
                % The timer trigers can be used to interpolate triggers from the EEG to the eyetracking data
                et_trgs.sample_fmri = round(interp1(eeg_trg_timer, et_trgs.sample_timer, eeg_trg_fmri))';
                et_trgs.sample_fmri(isnan(et_trgs.sample_fmri)) = [];
                et_trgs.time_fmri = et_data(et_trgs.sample_fmri, 1);

                %% Add events and triggers to data array
                fixations = create_event_vector(et_events, length(et_data), 'fix_sample');
                saccades = create_event_vector(et_events,  length(et_data), 'sac_sample');
                blinks = create_event_vector(et_events,  length(et_data), 'bl_sample');

                trg_on_off = zeros(length(et_data),1);
                trg_on_off(et_trgs.sample_on) = 1;
                trg_on_off(et_trgs.sample_off) = 1;

                trg_timer = zeros(length(et_data),1);
                trg_timer(et_trgs.sample_fmri) = 1;

                trg_fmri = zeros(length(et_data),1);
                trg_fmri(et_trgs.sample_fmri) = 1;

                et_data = [et_data, fixations, saccades, blinks, trg_on_off, trg_timer, trg_fmri];

                metadata.Columns = [metadata.Columns, 'Fixations', 'Saccades', 'Blinks', ...
                    'Task On-Off Trigger', '1s Timer Trigger', 'fMRI Volume Trigger'];

                %% Write the eyetracking data in BIDS format
                % Jason file for metadata
                save_et_bids_metadata(metadata, options.et_dir, strrep(et_files(f).name, '_eyelink.edf', sprintf('%s.json', options.eye_file_label)))
                
                % Data file 
                save_et_bids_data(et_data, options.et_dir, strrep(et_files(f).name, '_eyelink.edf', sprintf('%s.tsv', options.eye_file_label)))
        
                %% Check time alignment
                % Get time of task
                eeg_time_task = (eeg_trg_off - eeg_trg_on) / EEG.srate;
                et_time_task = et_trgs.time_off - et_trgs.time_on;  
            
                % Time difference
                if ~isempty(eeg_time_task) && ~isempty(et_time_task)
                    eeg_et_sample_diff = [eeg_et_sample_diff; (eeg_time_task - et_time_task) * EEG.srate];
                end
        
                %% Quality metrics
                % Samples without data
                percent_missing_samples = [percent_missing_samples; ...
                    sum(isnan(et_data(:,ismember(metadata.Columns, 'Gaze X')))) / length(et_data)];
        
                % Samples with gaze position outside of the screen
                out_of_screen_x = sum(et_data(:,ismember(metadata.Columns, 'Gaze X')) < metadata.DisplayCoordinates(2) | ...
                    et_data(:,ismember(metadata.Columns, 'Gaze X')) > metadata.DisplayCoordinates(4));
                out_of_screen_y = sum(et_data(:,ismember(metadata.Columns, 'Gaze Y')) < metadata.DisplayCoordinates(1) | ...
                    et_data(:,ismember(metadata.Columns, 'Gaze Y')) > metadata.DisplayCoordinates(3));
        
                percent_out_samples = [percent_out_samples; ...
                    (out_of_screen_x + out_of_screen_y) / length(et_data)];
        
                % Save the quality control data
                file_names = [file_names; et_files(f).name];
        
                save(eeg_et_sample_diff_file, 'eeg_et_sample_diff', 'file_names');
                save(percent_missing_samples_file, 'percent_missing_samples', 'file_names');
                save(percent_out_samples_file, 'percent_out_samples', 'file_names');
                save(missing_eeg_file, 'missing_eeg');
    
            end
    
        end
    end
    
    %% Double check the files
    error_file = sprintf('%s/data_errors.mat', options.res_dir);

    if exist(error_file, 'file') == 0

        json_error = table;
        error_columns = {'File', 'Field_SamplingFrequency', 'Field_StartTime', 'Field_Columns', 'Field_Manufacturer', ...
            'Field_ManufacturersModelName', 'Field_SoftwareVersions', 'Field_DeviceSerialNumber', 'Field_DisplayCoordinates', ...
            'Var_SamplingFrequency', 'Var_StartTime', 'Var_Columns', 'Var_Manufacturer', ...
            'Var_ManufacturersModelName', 'Var_SoftwareVersions', 'Var_DeviceSerialNumber', 'Var_DisplayCoordinates'};
        
        data_error = {};
        
        for sub = 1:length(subs)
            for ses = 1:length(sessions{sub})
        
                % List all .edf files
                options.et_dir = sprintf('%s/%s/%s/%s', options.raw_dir, subs(sub).name, sessions{sub}{ses}, options.eye_dir);
                et_files = dir(options.et_dir);
        
                data_files = et_files(cellfun(@(C) contains(C, sprintf('%s.tsv.gz', options.eye_file_label)), {et_files.name}));
                meta_files = et_files(cellfun(@(C) contains(C, sprintf('%s.json', options.eye_file_label)), {et_files.name}));
        
                if length(data_files) ~= length(meta_files)
                    error('Data or metadata files are missing!')
                end
        
                for f = 1:length(data_files)
        
                    %% Check content of the .json file
                    metadata = load_et_bids_metadata(options.et_dir, meta_files(f).name);
                
                    row = table(string(meta_files(f).name), 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, ...
                        'VariableNames', error_columns);
                
                    row = check_json_field(row, metadata, 'SamplingFrequency');
                    row = check_json_field(row, metadata, 'StartTime');
                    row = check_json_field(row, metadata, 'Columns');
                    row = check_json_field(row, metadata, 'Manufacturer');
                    row = check_json_field(row, metadata, 'ManufacturersModelName');
                    row = check_json_field(row, metadata, 'SoftwareVersions');
                    row = check_json_field(row, metadata, 'DeviceSerialNumber');
                    row = check_json_field(row, metadata, 'DisplayCoordinates');
                
                    if sum(table2array(row(:,2:end)) == 1) ~= (size(row,2)-1)
                        json_error = [json_error; row];
                    end
                
                    %% Check content of the data file      
                    data = load_et_bids_data(options.et_dir, data_files(f).name);
    
                    if isempty(data)
                        data_error = [data_error; et_files(f).name];
                    end
    
                end
        
            end
        end
        
        save(error_file, 'json_error', 'data_error')

    end
    
    %% Quality control summary
    if options.plot_qc
    
        load(percent_missing_samples_file, 'percent_missing_samples')
    
        figure('Position', [2000,300,350,400])
        hold on
        
        scatter(0.02*randn(length(percent_missing_samples),1) + 1, 100*percent_missing_samples, 'k.')
        plot([-0.07 0.07] + 1, [1 1]*median(100*percent_missing_samples), 'r--', 'LineWidth',2)
        
        xlim([-0.15 0.15] + 1)
        xticks([])
    
        grid on, grid minor
    
        ylabel('% missing samples')
        set(gca, 'FontSize', 16)
    
        saveas(gca, sprintf('%s/percent_missing_samples.png', options.fig_dir))
        
        % Samples outside screen
        load(percent_out_samples_file, 'percent_out_samples')
        
        figure('Position', [2000,300,350,400])
        hold on
        
        scatter(0.02*randn(length(percent_out_samples),1) + 1, 100*percent_out_samples, 'k.')
        plot([-0.07 0.07] + 1, [1 1]*median(100*percent_out_samples), 'r--', 'LineWidth',2)
        
        xlim([-0.15 0.15] + 1)
        ylim([0 100])
        xticks([])
    
        grid on, grid minor
    
        ylabel('% samples outside screen')
        set(gca, 'FontSize', 16)
    
        saveas(gca, sprintf('%s/percent_out_samples.png', options.fig_dir))
    
    end

end