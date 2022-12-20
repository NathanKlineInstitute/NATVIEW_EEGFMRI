%% Delete data
function delete_data(options)

    %% Setup
    % List subjects and sessions
    [subs, sessions] = list_sub_ses(options.raw_dir);

    for sub = 1:length(subs)
        for ses = 1:length(sessions{sub})
    
            % List all eyetracking files in raw data directory
            options.et_dir = sprintf('%s/%s/%s/%s', options.raw_dir, subs(sub).name, sessions{sub}{ses}, options.eye_dir);
            et_files = dir(options.et_dir);
            et_files = et_files(cellfun(@(C) contains(C, {options.eye_file_label, 'eyelink', 'eye'}), {et_files.name})); 
    
            for f = 1:length(et_files)

                if ispc
                    system(sprintf('del %s/%s', options.et_dir, et_files(f).name));
                else
                    system(sprintf('rm %s/%s', options.et_dir, et_files(f).name));
                end

            end

            % Delete preprocessed data
            options.et_dir = sprintf('%s/%s/%s/%s', options.preproc_dir, subs(sub).name, sessions{sub}{ses}, options.eye_dir);
            et_files = dir(options.et_dir);
            et_files = et_files(cellfun(@(C) contains(C, {options.eye_file_label, 'eyelink', 'eye'}), {et_files.name})); 
    
            for f = 1:length(et_files)

                if ispc
                    system(sprintf('del %s/%s', options.et_dir, et_files(f).name));
                else
                    system(sprintf('rm %s/%s', options.et_dir, et_files(f).name));
                end

            end

        end
    end

end