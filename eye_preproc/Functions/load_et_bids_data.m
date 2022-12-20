%% Load eyetracking data from BIDS .tsv.gz file
function data = load_et_bids_data(file_dir, file_name)

    data_file = sprintf('%s/%s', file_dir, file_name);
    
    % Unzip
    gunzip(data_file);
    
    data_unzip = strrep(data_file, 'tsv.gz', 'tsv');
    
    % Change file ending to .csv
    if ispc
        data_unzip = strrep(data_unzip, '/', '\');
        system(sprintf('copy %s %s', data_unzip, strrep(data_unzip, '.tsv', '.csv')));
        system(sprintf('del %s', data_unzip));
    else
        system(sprintf('cp %s %s', data_unzip, strrep(data_unzip, '.tsv', '.csv')));
        system(sprintf('rm %s', data_unzip));
    end
    
    % Read data
    data = readtable(strrep(data_unzip, 'tsv', 'csv'));
    
    % Delete unziped file
    if ispc
        data_unzip = strrep(strrep(data_unzip, '.tsv', '.csv'), '/', '\');
        system(sprintf('del %s', data_unzip));
    else
        system(sprintf('rm %s', strrep(data_unzip, '.tsv', '.csv')));
    end

end