%% Save eyetracking data in BIDS .tsv.gz file
function save_et_bids_data(data, file_dir, file_name)

    et_file = sprintf('%s/%s', file_dir, file_name);
    dlmwrite(et_file, data, '\t');
    
    % Compress the file
    gzip(et_file)
    
    if ispc
        et_file = strrep(et_file, '/', '\');
        system(sprintf('del %s', et_file));
    else
        system(sprintf('rm %s', et_file));
    end

end