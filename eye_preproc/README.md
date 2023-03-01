### Conversion of eyetracking data to BIDS format and preprocessing

Data in eyelink format is not provided. The code for conversion to BIDS format is provided for documentation. Raw eyetracking data was available in eyelink .edf files and was processed using the [EyeLink Developers Kit](https://www.sr-research.com/support/thread-13.html).

Eyetracking data is aligned to the EEG data. Therefore, EEG files have to be loaded, requiring [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php). 

Data can be downloded automatically through the script using the [Cyberduck command line interface (CLI)](https://duck.sh/). This has only been tested on Linux. 

If the data is downloaded manually, at least the raw eyetracking data and the preprocessed EEG data is necessary. Place both BIDS folders in the same directory. A prompt will ask to select this directory when running eye_preproc_pipeline.m. 

Raw eyetracking data is available here: s3://fcp-indi/data/Projects/NATVIEW_EEGFMRI/raw_data

Preprocessed EEG data is available here: s3://fcp-indi/data/Projects/NATVIEW_EEGFMRI/preproc_data

In addition, to align the eyetracking recordings to videos, the video files need to be downloaded from: https://fcon_1000.projects.nitrc.org/indi/retro/NAT_VIEW/videos.tar.gz, and placed in the same directory as the eyetracking and EEG data.
