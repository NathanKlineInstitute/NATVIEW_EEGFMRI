
function trgs = read_eeg_trg(eeg_file, options)

    % Split file path and name
    [eeg_dir, eeg_file] = fileparts(eeg_file);
    eeg_file = sprintf('%s.set', eeg_file);

    % Define the output file 
    trg_file = sprintf('%s/%s', options.res_dir, strrep(eeg_file, '_eeg.set', '_eeg_trgs.mat'));

    if exist(trg_file, 'file') == 0
    
        try
            EEG = pop_loadset(eeg_file, eeg_dir);
        catch
            save(sprintf('%s/%s', options.res_dir, strrep(eeg_file, '.set', '_missing_eeg.mat')), 'eeg_file')
            trgs = [];
            return
        end
        
        % Reconstruct time axis
        EEG.times = 0:1/EEG.srate:(length(EEG.etc.clean_sample_mask)-1)/EEG.srate;
        
        %% EEG triggers 
        % Load trigger information
        trigger_table = readtable('./Organize/trigger_ids.xlsx');
        
        trigger_table = trigger_table(cellfun(@(C) contains(eeg_file, C, 'IgnoreCase', true), trigger_table.bids_name), :);
        
        idx_eeg = cellfun(@(C) contains('eeg', C), trigger_table.data_type); 
        
        eeg_trg_samples = round([EEG.urevent.latency]);
        eeg_trg_id = {EEG.urevent.type};
        
        trgs.eeg_trg_on = eeg_trg_samples(ismember(eeg_trg_id, trigger_table.task_start{idx_eeg}));
        trgs.eeg_trg_off = eeg_trg_samples(ismember(eeg_trg_id, trigger_table.task_end{idx_eeg}));
    
        % Other EEG triggers
        trgs.eeg_trg_timer = eeg_trg_samples(ismember(eeg_trg_id, trigger_table.timer_1{idx_eeg}));
        trgs.eeg_trg_fmri = eeg_trg_samples(ismember(eeg_trg_id, 'R128'));
    
        trgs.eeg_trg_on_time = EEG.times(trgs.eeg_trg_on);
    
        % Sampling rate
        trgs.eeg_srate = EEG.srate;
    
        % Save the trigger data
        save(trg_file, 'trgs')

    % Load the data if it was already computed
    else
        load(trg_file, 'trgs')
    end

end