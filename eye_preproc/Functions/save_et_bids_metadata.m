%% Save eyetracking metadata in BIDS .json file
function save_et_bids_metadata(metadata, file_dir, file_name)

    json_file = fopen(sprintf('%s/%s', file_dir, file_name), 'w');
    fprintf(json_file, jsonencode(metadata, "PrettyPrint", true)); 
    fclose(json_file); 

end