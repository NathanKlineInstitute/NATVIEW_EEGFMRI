function add_eeglab()

    eeglab_dir = uigetdir('/home/max/Documents/Dropbox (City College)/Code/Master', 'Select the directory containing EEGlab');
    addpath(eeglab_dir);
    
    try
        pop_newset([], [], 1, 'gui', 'off');
        close all
    catch
        eeglab
        close all
    end

end