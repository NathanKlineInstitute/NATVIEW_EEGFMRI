%% Check content of eyetracking files
function [metadata_error, data_error] = check_et(et_file, options)

    % At default there are no errors
    metadata_error = 0;
    data_error = 0;

    %% Check content of the .json file
    meta_file = strrep(et_file, '.tsv.gz', '.json');

    metadata = load_et_bids_metadata(options.et_dir, meta_file);

    error_columns = {'File', 'Field_SamplingFrequency', 'Field_StartTime', 'Field_Columns', 'Field_Manufacturer', ...
        'Field_ManufacturersModelName', 'Field_SoftwareVersions', 'Field_DeviceSerialNumber', 'Field_DisplayCoordinates', ...
        'Var_SamplingFrequency', 'Var_StartTime', 'Var_Columns', 'Var_Manufacturer', ...
        'Var_ManufacturersModelName', 'Var_SoftwareVersions', 'Var_DeviceSerialNumber', 'Var_DisplayCoordinates'};
    
    row = table(string(meta_file), 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, ...
        'VariableNames', error_columns);
    
    row = check_json_field(row, metadata, 'SamplingFrequency');
    row = check_json_field(row, metadata, 'StartTime');
    row = check_json_field(row, metadata, 'Columns');
    row = check_json_field(row, metadata, 'Manufacturer');
    row = check_json_field(row, metadata, 'ManufacturersModelName');
    row = check_json_field(row, metadata, 'SoftwareVersions');
    row = check_json_field(row, metadata, 'DeviceSerialNumber');
    row = check_json_field(row, metadata, 'DisplayCoordinates');
    
    if sum(table2array(row(:,2:end)) == 1) ~= (size(row,2)-1)
        metadata_error = 1;
        save(sprintf('%s/%s', options.res_dir, strrep(et_file, '.tsv.gz', '_metadata_error.mat')), 'metadata_error')
    end
    
    %% Check content of the data file      
    data = load_et_bids_data(options.et_dir, et_file);
    
    if isempty(data)
        data_error = 1;
        save(sprintf('%s/%s', options.res_dir, strrep(et_file, '.tsv.gz', '_data_error.mat')), 'data_error')
    end

end