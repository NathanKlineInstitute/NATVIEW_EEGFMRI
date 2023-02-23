# NATVIEW_EEGFMRI
Welcome! Here you will find code for preprocessing simultaneous EEG-fMRI data that is part of the Naturalistic Viewing EEG-FMRI (NATVIEW_EEGFMRI) data release from the [Nathan S. Kline Institute for Psychiatric Research](https://www.nki.rfmh.org/).

The data release includes:
1. Electroencephalography (EEG)
2. Functional Magnetic Resonance Imaging (FMRI)
3. EyeLink Eye Tracking Data
4. Biopac Respiratory Data

Included here on this Github repository are various MATLAB scripts, Bash scripts and files related to preprocessing simultaneously collected data. Below you will find a description of the various modalities and their associated code.

***NOTE: This code is for preprocessing the NATVIEW_EEGFMRI data set with files organized in the [Brain Imaging Data Structure (BIDS)](https://bids.neuroimaging.io/) format. These preprocessing steps can be applied to any simultaneously collected EEG data, but code modification required if file is not in BIDS format.***

## EEG
Contains MATLAB script for preprocessing EEG data collected in the NATVIEW_EEGFMRI data release. This script requires [EEGLAB](https://sccn.ucsd.edu/eeglab/index.php) and the [FMRIB Plug-In for EEGLAB](https://fsl.fmrib.ox.ac.uk/eeglab/fmribplugin/).
* ***natview_eeg_preprocess_pipeline.m***: MATLAB script for preprocessing EEG data collected inside MRI scanner. Script performs gradient artifact removal, QRS detection/pulse artifact removal, and various filtering steps for cleaning data.
* ***BC-MR-64-X52.bvef***: Includes the electrode name as well as their physical channel order for cap montage. This cap was modified to include two EOG electrodes (EOGL and EOGU) below and above the left eye.

## fMRI
Contains code from [Connectome Computation System (CCS) preprocessing pipeline](https://github.com/TingsterX/CCS-pipeline).

## Stimulus
Contains two MATLAB scripts for stimulus presentation. These scripts use various functions from [Psychtoolbox-3](http://psychtoolbox.org/) for a flickering checkerboard task, resting state task, and video task. Code has also been modified to work with the EyeLink 1000 Plus eye tracker by [SR Research](https://www.sr-research.com/).
* ***natview_stimuli_checkerboard.m***: MATLAB script for presenting flickering checkerboard stimulus. Task uses a block design with a period of rest followed by a period of a flickering circular checkerboard. User can define the flicker frequency, duration of stimulus period, the number of rest-checkerboard blocks, and checkerboard parameters (grid size and spokes).
* ***natview_stimuli_video.m***: MATLAB script for presenting video or resting state scan. This code works with videos specific to the the NATVIEW_EEGFMRI dataset, but user can specify different displays video (or crosshair for resting state)  
  - _NOTE: This MATLAB code works with the EyeLink eye tracker, but contain flags to run without eye tracking. User still needs to modify code to work with their respective computer and/or scanning system._
