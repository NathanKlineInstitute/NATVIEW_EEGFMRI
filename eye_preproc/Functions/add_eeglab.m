function add_eeglab(eeglab_dir)

    addpath(eeglab_dir);
    
    try
        pop_newset([], [], 1, 'gui', 'off');
        close all
    catch
        eeglab
        close all
    end

end