### Conversion of eyetracking data to BIDS format and preprocessing

Data in eyelink format is not provided. The code for conversion to BIDS format is provided for documentation. Raw eyetracking data was available in eyelink .edf files and was processed using the [EyeLink Developers Kit](https://www.sr-research.com/support/thread-13.html)

Eyetracking data is aligned to the EEG data. Therefore, EEG files have to be loaded, requiring [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php). 

Data can be downloded automatically through the script using the [Cyberduck command line interface (CLI)](https://duck.sh/). This has only been tested on Linux. 
