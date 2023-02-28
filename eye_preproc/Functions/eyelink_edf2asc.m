%% Convert .edf files to .asc
function eyelink_edf2asc(edf_file)

    % Define the name of the output file
    asc_file = strrep(edf_file, '.edf', '.asc');

    % Convert the file if it doesn't exist 
    if exist(asc_file, 'file') == 0
        system(sprintf('edf2asc -y -res %s', edf_file));
    end

end