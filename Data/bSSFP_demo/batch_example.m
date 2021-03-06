% Batch to process bSSFP_modulaire data without qMRLab GUI (graphical user interface)
% Run this script line by line
% Written by: Ian Gagnon, 2017

%% Load dataset

% Load your parameters to create your Model
% load('MODELPamameters.mat');
load('bSSFPParameters.mat');

%% Check data and fitting (Optional)

%**************************************************************************
% I- GENERATE FILE STRUCT
%**************************************************************************
% Create a struct "file" that contains the NAME of all data's FILES
% file.DATA = 'DATA_FILE';
file.MTdata = 'MTdata.nii';
file.R1map = 'R1map.nii';
file.Mask = 'Mask.nii';

%**************************************************************************
% II- CHECK DATA AND FITTING
%**************************************************************************
qMRLab(Model,file);


%% Create Quantitative Maps

%**************************************************************************
% I- LOAD PROTOCOL
%**************************************************************************

% MTdata
Alpha = [ 5      ; 10     ; 15     ; 20     ; 25     ; 30     ; 35     ; 40     ; 35     ; 35     ; 35     ; 35     ; 35     ; 35     ; 35    ; 35     ];
Trf   = [ 2.7e-4 ; 2.7e-4 ; 2.7e-4 ; 2.7e-4 ; 2.7e-4 ; 2.7e-4 ; 2.7e-4 ; 2.7e-4 ; 2.3e-4 ; 3.0e-4 ; 4.0e-4 ; 5.8e-4 ; 8.4e-4 ; 0.0012 ;0.0012 ; 0.0021 ];
Model.Prot.MTdata.Mat = [Alpha,Trf];

% *** To change other option, go directly in qMRLab ***

% Update the model
Model = Model.UpdateFields;

%**************************************************************************
% II- LOAD EXPERIMENTAL DATA
%**************************************************************************
% Create a struct "data" that contains all the data
% .MAT file : load('DATA_FILE');
%             data.DATA = double(DATA);
% .NII file : data.DATA = double(load_nii_data('DATA_FILE'));
data.MTdata = double(load_nii_data('MTdata.nii'));
data.R1map = double(load_nii_data('R1map.nii'));
data.Mask   = double(load_nii_data('Mask.nii'));

%**************************************************************************
% III- FIT DATASET
%**************************************************************************
FitResults       = FitData(data,Model,1); % 3rd argument plots a waitbar
FitResults.Model = Model;
delete('FitTempResults.mat');

%**************************************************************************
% IV- CHECK FITTING RESULT IN A VOXEL
%**************************************************************************
figure
voxel           = [50, 70, 1];
FitResultsVox   = extractvoxel(FitResults,voxel,FitResults.fields);
dataVox         = extractvoxel(data,voxel);
Model.plotmodel(FitResultsVox,dataVox)

%**************************************************************************
% V- SAVE
%**************************************************************************
% .MAT file : FitResultsSave_mat(FitResults,folder);
% .NII file : FitResultsSave_nii(FitResults,fname_copyheader,folder);
FitResultsSave_nii(FitResults,'MTdata.nii');
save('Parameters.mat','Model');

%% Check the results
% Load them in qMRLab
