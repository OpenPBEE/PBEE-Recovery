% This script facilitates the performance based functional recovery and
% reoccupancy assessment of a single building for a single intensity level

% Input data consists of building model info and simulated component-level
% damage and conesequence data for a suite of realizations, likely assessed
% as part of a FEMA P-58 analysis. Inputs are read in as matlab variables
% direclty from matlab data files, as well as loaded from csvs in the
% static_tables directory.

% Output data is saved to a specified outputs directory and is saved into a
% single matlab variable as at matlab data file.

clear
close all
clc 
rehash

%% Define User Inputs
model_name = 'ICSB'; % Name of the model;
                     % inputs are expected to be in a directory with this name
                     % outputs will save to a directory with this name
model_dir = ['inputs' filesep 'example_inputs']; % Directory where the simulated inputs are located
outputs_dir = ['outputs' filesep model_name]; % Directory where the assessment outputs are saved

%% Load FEMA P-58 performance model data and simulated damage and loss
load([model_dir filesep model_name filesep 'simulated_inputs.mat'])

%% Load required static data
systems = readtable(['static_tables' filesep 'systems.csv']);
subsystems = readtable(['static_tables' filesep 'subsystems.csv']);
impeding_factor_medians = readtable(['static_tables' filesep 'impeding_factors.csv']);
tmp_repair_class = readtable(['static_tables' filesep 'temp_repair_class.csv']);
        
%% Run Recovery Method
[functionality] = main_PBEErecovery(damage, damage_consequences, ...
    building_model, tenant_units, systems, subsystems, tmp_repair_class, ...
    impedance_options, impeding_factor_medians, repair_time_options, ...
    functionality, functionality_options);

%% Save Outputs
if ~exist(outputs_dir,'dir')
    mkdir(outputs_dir)
end
save([outputs_dir filesep 'recovery_outputs.mat'],'functionality')
fprintf('Recovery assessment of model %s complete\n',model_name)
