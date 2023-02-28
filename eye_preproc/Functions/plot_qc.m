%% Make figures of quality control data
function plot_qc(options)
    
    %% Missing samples
    % List all files
    qc_files = dir(options.res_dir);
    
    % Load percent of missing samples for each recording
    missing_samples_files = qc_files(cellfun(@(C) contains(C, 'percent_missing_samples.mat'), {qc_files.name}));
    
    percent_missing_samples_all = [];
    for f = 1:length(missing_samples_files)
        load(sprintf('%s/%s', options.res_dir, missing_samples_files(f).name), 'percent_missing_samples')
        percent_missing_samples_all = [percent_missing_samples_all; percent_missing_samples];
    end
    
    % Make the figure for missing samples
    figure('Position', [2000,300,350,400])
    hold on
    
    scatter(0.02*randn(length(percent_missing_samples_all),1) + 1, 100*percent_missing_samples_all, 'k.')
    plot([-0.07 0.07] + 1, [1 1]*median(100*percent_missing_samples_all), 'r--', 'LineWidth',2)
    
    xlim([-0.15 0.15] + 1)
    xticks([])
    
    grid on, grid minor
    
    ylabel('% missing samples')
    set(gca, 'FontSize', 16)
    
    saveas(gca, sprintf('%s/percent_missing_samples.png', options.fig_dir))
    
    % Load number of samples outside the screen
    missing_samples_files = qc_files(cellfun(@(C) contains(C, 'percent_out_samples.mat'), {qc_files.name}));
    
    percent_out_samples_all = [];
    for f = 1:length(missing_samples_files)
        load(sprintf('%s/%s', options.res_dir, missing_samples_files(f).name), 'percent_out_samples')
        percent_out_samples_all = [percent_out_samples_all; percent_out_samples];
    end
    
    figure('Position', [2000,300,350,400])
    hold on
    
    scatter(0.02*randn(length(percent_out_samples_all),1) + 1, 100*percent_out_samples_all, 'k.')
    plot([-0.07 0.07] + 1, [1 1]*median(100*percent_out_samples_all), 'r--', 'LineWidth',2)
    
    xlim([-0.15 0.15] + 1)
    ylim([0 100])
    xticks([])
    
    grid on, grid minor
    
    ylabel('% samples outside screen')
    set(gca, 'FontSize', 16)
    
    saveas(gca, sprintf('%s/percent_out_samples.png', options.fig_dir))

    %% Video alignment
    file_order = readtable('./Organize/file_order.xlsx');
    vids = unique(file_order.name);

    align_files = dir(options.align_dir);

    for v = 1:length(vids)
        
        bids_label = file_order.bids_name(ismember(file_order.name, vids{v}));
        
        files_vid = align_files(cellfun(@(C) contains(C, bids_label), {align_files.name}));

        length_vid = [];
        for f = 1:length(files_vid)
            load(sprintf('%s/%s', options.align_dir, files_vid(f).name), 'time_eye')
            length_vid = [length_vid; time_eye];
        end

        if isempty(length_vid), continue, end

        figure
        histogram(length_vid, 50)
    
        title(strrep(vids{v}, '_', ' '))
        xlabel('Time [s]')
        ylabel('Number of recordings')
        set(gca, 'FontSize', 12)
    
        grid on, grid minor
    
        saveas(gca, sprintf('%s/%s_video_recording_length.png', options.fig_align_dir, vids{v}))

    end
    
end