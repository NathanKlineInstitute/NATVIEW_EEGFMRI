%% Compute movie metadata
function compute_vid_metadata(options)

    vid_meta_file = sprintf('%s/vid_metadata.mat', options.align_dir);
    
    if exist(vid_meta_file, 'file') == 0
    
        vid_files = dir(options.vid_dir);
        vid_files([vid_files.isdir]) = [];
        
        vid_fr = nan(1, length(vid_files));
        vid_T = nan(1, length(vid_files));
        vid_nfr = nan(1, length(vid_files));
        
        for v = 1:length(vid_files)
            vid = VideoReader(sprintf('%s/%s', options.vid_dir, vid_files(v).name));
            vid_fr(v) = vid.FrameRate;
            vid_T(v) = vid.Duration;
            vid_nfr(v) = vid.NumFrames;
        end
        
        vid_names = {vid_files.name};
        
        save(vid_meta_file, 'vid_fr', 'vid_T', 'vid_names', 'vid_nfr')
        
    end

end