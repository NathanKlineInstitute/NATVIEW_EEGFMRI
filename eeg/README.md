## EEG Preprocessing Pipeline
These instructions will show user how to preprocess EEG data from the NATVIEW_EEGFMRI data release. This script can also work on EEG data collected by user, provided the filename is in [BIDS](https://bids.neuroimaging.io/) format. User must download and install [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php) and the [FMRIB Plug-In for EEGLAB](https://fsl.fmrib.ox.ac.uk/eeglab/fmribplugin/) to properly run this script.

***Example 1***:

> Raw EEG data saved to: ```/data/eeg/sub-01/ses-01/sub-01_ses-01_task-checker_eeg.set```
>
> In MATLAB Command Window:
> ```
> >> fileNameSET = '/data/eeg/sub-01/ses-01/sub-01_ses-01_task-checker_eeg.set';
> >> outputDir = '/data/eeg/preprocess/sub-01/ses-01';
> >> saveInterMediates = 1;
> >> options.step1_gradient = 1; options.step2b_pulse = 1;
> >> EEG = natview_eeg_preprocess_pipeline(fileNameSET,outputDir,saveIntermediates,options);
> ```
> Preprocessed EEG data saved to: ```/data/eeg/sub-01/ses-01/preprocess/```
>
> Output files:
> 1. ```/data/eeg/preprocess/sub-01/ses-01/sub-01_ses-01_task-checker_preprocess_eeg.set```
> 2. ```/data/eeg/preprocess/sub-01/ses-01/sub-01_ses-01_task-checker_preprocess-1gradient_eeg.set```
> 3. ```/data/eeg/preprocess/sub-01/ses-01/sub-01_ses-01_task-checker_preprocess-2bpulse_eeg.set```
> 
> The above example is running preprocessing on simultaneous EEG data from a recording of the checkerboard stimulus. User saves preprocessed data, including intermediates for the gradient artifact removal and pulse artifact removal step.

***Example 2***:
> Raw EEG data saved to: ```/data/eeg/sub-05/ses-02/sub-05_ses-02_task-dmh_run-01_eeg.set```
> 
> In MATLAB Command Window:
> ```
> >> fileNameSET = '/data/eeg/sub-05/ses-02/sub-05_ses-02_task-dmh_run-01_eeg.set';
> >> outputDir = '/data/eeg/preprocess/sub-05/ses-02/';
> >> saveInterMediates = 1;
> >> options.step5_bandpass;
> >> EEG = natview_eeg_preprocess_pipeline(fileNameSET,outputDir,saveIntermediates,options);
> ```
> Preprocessed EEG data saved to: ```/data/eeg/preprocess/sub-05/ses-02```
> 
> Output files:
> 1. ```/data/eeg/preprocess/sub-05/ses-02/sub-05_ses-02_task-dmh_run-01_preprocess_eeg.set```
> 2. ```/data/eeg/preprocess/sub-05/ses-02/sub-05_ses-02_task-dmh_run-01_preprocess-5bandpass_eeg.set```
> 
> The above example is running preprocessing on simultaneous EEG data from a recording of the checkerboard stimulus. User saves preprocessed data, including intermediate for the bandpass filtering step.
