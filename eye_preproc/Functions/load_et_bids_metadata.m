%% Load eyetracking metadata from BIDS .json file
function metadata = load_et_bids_metadata(file_dir, file_name)

    file_id = fopen(sprintf('%s/%s', file_dir, file_name));
    json_content = char(fread(file_id, inf)'); 
    fclose(file_id);
    
    metadata = jsondecode(json_content);

    metadata.Columns = metadata.Columns';

end