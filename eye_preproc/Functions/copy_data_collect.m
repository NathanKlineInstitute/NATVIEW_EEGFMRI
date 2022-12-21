%% Copy data from BIDS structure folders to one directory

function copy_data_collect(options, file_identifier, origin_dir, target_dir)
    
    % List subjects and sessions
    [subs, sessions] = list_sub_ses(origin_dir);
    
    % Create the output directory
    if exist(target_dir, 'dir') == 0, mkdir(target_dir), end
    
    % Copy all files
    for sub = 1:length(subs) 
        for ses = 1:length(sessions{sub})
    
            % List all files
            et_dir = sprintf('%s/%s/%s/%s', origin_dir, subs(sub).name, sessions{sub}{ses}, options.eye_dir);
            et_files = dir(et_dir);
            et_files = et_files(cellfun(@(C) contains(C, file_identifier), {et_files.name})); 
            
            for f = 1:length(et_files)
    
                % Copy the data
                if ispc
                    sys_et_dir = strrep(et_dir, '/', '\');
                    sys_raw_collect_dir = strrep(target_dir, '/', '\');
                    system(sprintf('copy %s\\%s %s\\%s', sys_et_dir, et_files(f).name, sys_raw_collect_dir, et_files(f).name));
                else
                    system(sprintf('cp %s/%s %s/%s', et_dir, et_files(f).name, target_dir, et_files(f).name));
                end
    
            end
    
        end
    
    end

end