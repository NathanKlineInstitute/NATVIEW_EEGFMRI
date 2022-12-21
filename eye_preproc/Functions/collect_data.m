%% Collect preprocessed data in a single folder

function collect_data(options)

    %% Copy raw data
    copy_data_collect(options, options.eye_file_label, options.raw_dir, sprintf('%s/raw_bids', options.collect_dir))

    %% Copy the preprocessed data
    copy_data_collect(options, options.eye_file_label, options.preproc_dir, sprintf('%s/preproc_bids', options.collect_dir))

    %% Copy the video aligned data
    eye_file_parts = strsplit(options.eye_file_label, '_');
    eye_file_parts(cellfun(@(C) isempty(C), eye_file_parts)) = [];

    aligned_identifier = sprintf('_%s_video_aligned_%s', eye_file_parts{1}, eye_file_parts{2});

    copy_data_collect(options, aligned_identifier, options.preproc_dir, sprintf('%s/video_aligned_bids', options.collect_dir))

end