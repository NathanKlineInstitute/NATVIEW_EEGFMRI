%% Download specific eyetracking data from AWS bucket using cyberduck CLI 
% Tested on Linux

function download_eye_data(options)
    
    % List all subjects
    fprintf('Listing subjects ...\n')
    [~, console_out] = system(sprintf('duck --anonymous --list %s/raw_data/', options.bucket_address));
    
    subs = extract_str_pattern(console_out, 'sub-', 1);
    
    % List sessions for each subject
    ses = cell(length(subs), 1);
    
    for s = 1:length(subs)
        fprintf('Listing sessions for subject %s ...\n', subs{s})
        [~, console_out] = system(sprintf('duck --anonymous --list %s/raw_data/%s/', options.bucket_address, subs{s}));
        ses{s} = extract_str_pattern(console_out, 'ses-', 1);
    end
    
    % Download select data
    for s1 = 1:length(subs)
        for s2 = 1:length(ses{s1})

            % Get the preprocessed EEG data
            system(sprintf('duck --anonymous --download %s/preproc_data/%s/%s/eeg/ %s/%s/%s/eeg', ...
                options.bucket_address, subs{s1}, ses{s1}{s2}, options.preproc_dir, subs{s1}, ses{s1}{s2}))
            
            % Select subjects
            if ~ismember('all', options.sub_select) && sum(ismember(options.sub_select, subs(s1))) == 0
                continue
            end
    
            % List all files
            [~, console_out] = system(sprintf('duck --anonymous --list %s/raw_data/%s/%s/eeg/', ...
                options.bucket_address, subs{s1}, ses{s1}{s2}));
    
            file_start_pattern = 'sub-';
            file_end_pattern = '[m';
    
            idx_file_start = regexp(console_out, file_start_pattern);
            idx_file_end = regexp(console_out, file_end_pattern);
    
            idx_file_end(idx_file_end < idx_file_start(1)) = [];
    
            files = cell(length(idx_file_start), 1);
    
            for f = 1:length(idx_file_start)
                files{f} = console_out(idx_file_start(f):idx_file_end(f)-2);
            end
    
            % Select modality
            files_select = files(cellfun(@(C) contains(C, options.mod_select), files));
    
            % Select tasks and download files 
            for t = 1:length(options.task_select)
    
                % Select task
                if ~ismember('all', options.task_select)
                    files_task = files_select(cellfun(@(C) contains(C, sprintf('%s_', options.task_select{t})), files_select));
                else
                    files_task = files_select;
                end
    
                for i = 1:length(files_task)
    
                    out_dir = sprintf('%s/%s/%s/eeg', options.raw_dir, subs{s1}, ses{s1}{s2});
                    if exist(out_dir, 'dir') == 0, mkdir(out_dir), end
    
                    out_file = sprintf('%s/%s', out_dir, files_task{i});
    
                    if exist(out_file, 'file') ~= 0
                        continue
                    end
    
                    system(sprintf('duck --anonymous --download %s/raw_data/%s/%s/eeg/%s %s', ...
                        options.bucket_address, subs{s1}, ses{s1}{s2}, files_task{i}, out_file));
    
                end
    
            end
    
        end
    end

    %% Download the video data
    system(sprintf('duck --download %s/%s %s', options.video_address, options.video_folder, options.data_dir));

    % Unzip
    gunzip(sprintf('%s/%s', options.data_dir, options.video_folder))
    untar(sprintf('%s/%s', options.data_dir, strrep(options.video_folder, '.gz', '')), ...
        sprintf('%s/%s', options.data_dir, strrep(options.video_folder, '.tar.gz', '')))

    % Organize 
    vid_folder = strrep(options.video_folder, '.tar.gz', '');
    system(sprintf('mv -f %s/%s/%s/{.,}* %s/%s/', options.data_dir, vid_folder, vid_folder, options.data_dir, vid_folder));
    system(sprintf('rm -r %s/%s/%s', options.data_dir, vid_folder, vid_folder));
    system(sprintf('rm %s/%s', options.data_dir, strrep(options.video_folder, '.gz', '')));
    system(sprintf('rm %s/%s', options.data_dir, options.video_folder));


end