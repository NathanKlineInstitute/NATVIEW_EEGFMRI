%% Organize eyetracking data in BIDS folder structure

function organize_raw_data(options)

    % List all .edf files
    eye_files = dir(options.eyelink_dir);
    eye_files = eye_files(cellfun(@(C) contains(C, '.edf'), {eye_files.name}));
    
    for f = 1:length(eye_files)
        
        % Extract subject and session id
        sub_str = 'sub-';
        idx_sub_id = regexp(eye_files(f).name, sub_str) + length(sub_str);
        sub_id = str2double(eye_files(f).name(idx_sub_id:idx_sub_id+1));
    
        ses_str = 'ses-';
        idx_ses_id = regexp(eye_files(f).name, ses_str) + length(ses_str);
        ses_id = str2double(eye_files(f).name(idx_ses_id:idx_ses_id+1));
    
        % Define the target directory and create if not present
        sub_raw_dir = sprintf('%s/sub-%02d/ses-%02d/%s', options.raw_dir, sub_id, ses_id, options.eye_dir);
        if exist(sub_raw_dir, 'dir') == 0, mkdir(sub_raw_dir), end
    
        if exist(sprintf('%s/%s', sub_raw_dir, eye_files(f).name), 'file') ~= 0
            continue
        end

        % Copy the data
        if ispc
            sys_eyelink_dir = strrep(strrep(options.eyelink_dir, '/', '\'), 'Dropbox (City College)', '"Dropbox (City College)"');
            sys_raw_dir = strrep(sub_raw_dir, '/', '\');
            system(sprintf('copy %s\\%s %s\\%s', sys_eyelink_dir, eye_files(f).name, sys_raw_dir, eye_files(f).name));
        else
            sys_eyelink_dir = strrep(options.eyelink_dir, 'Dropbox (City College)', 'Dropbox\ \(City\ College\)');
            system(sprintf('cp %s/%s %s/%s', sys_eyelink_dir, eye_files(f).name, sub_raw_dir, eye_files(f).name));
        end
    
    end

end