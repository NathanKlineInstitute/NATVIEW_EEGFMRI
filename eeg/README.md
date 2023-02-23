## EEG Preprocessing Pipeline
These instructions will show user how to preprocess EEG data from the NATVIEW_EEGFMRI data release. This script can also work on EEG data collected by user, provided the filename is in [BIDS](https://bids.neuroimaging.io/) format. User must download and install [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php) and the [FMRIB Plug-In for EEGLAB](https://fsl.fmrib.ox.ac.uk/eeglab/fmribplugin/) to properly run this script.

***Example***:

Raw EEG data saved to: ```/data/eeg/sub-01/ses-01/sub-01_ses-01_task-checker_eeg.set```

In MATLAB Command Window:
```
>> fileNameSET = '/data/eeg/sub-01/ses-01/sub-01_ses-01_task-checker_eeg.set';
>> outputDir = '/data/eeg/sub-01/ses-01/preprocess';
>> saveInterMediates = 1;
>> options.step1_gradient = 1; options.step2b_pulse = 1;   
>> EEG = natview_eeg_preprocess_pipeline(fileNameSET,outputDir,saveIntermediates,options);
```
Preprocessed EEG data saved to: ```/data/eeg/sub-01/ses-01/preprocess/```

Output files:
1. ```/data/eeg/sub-01/ses-01/preprocess/sub-01_ses-01_task-checker_preprocess_eeg.set```
2. ```/data/eeg/sub-01/ses-01/preprocess/sub-01_ses-01_task-checker_preprocess-1gradient_eeg.set```
3. ```/data/eeg/sub-01/ses-01/preprocess/sub-01_ses-01_task-checker_preprocess-2bpulse_eeg.set```
