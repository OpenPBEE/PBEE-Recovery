% This script facilitates the performance based functional recovery and
% reoccupancy assessment of a single building for a single intensity level

% Input data consists of building model info and simulated component-level
% damage and conesequence data for a suite of realizations, likely assessed
% as part of a FEMA P-58 analysis. Inputs are read in as matlab variables
% direclty from matlab data files.

% Output data is saved to a specified outputs directory and is saved into a
% single matlab variable as at matlab data file.

clear
close all
fclose('all');
clc 
rehash

%% Define User Inputs
model_name = 'ICSB'; % Name of the model;
                     % inputs are expected to be in a directory with this name
                     % outputs will save to a directory with this name
model_dir = ['inputs' filesep 'example_inputs']; % Directory where the simulated inputs are located
outputs_dir = ['outputs' filesep model_name]; % Directory where the assessment outputs are saved

%% Import Packages
import recovery.repair_schedule.main_repair_schedule
import recovery.functionality.main_functionality

%% Load FEMA P-58 performance model data and simulated damage and loss
load([model_dir filesep model_name filesep 'simulated_inputs.mat'])

%% Load system and subsystem data
systems = readtable(['static_tables' filesep 'systems.csv']);
subsystems = readtable(['static_tables' filesep 'subsystems.csv']);

%% Calculate ATC 138 building repair schedule and impeding times
[damage, functionality.impeding_factors, functionality.worker_data, functionality.building_repair_schedule ] = ...
    main_repair_schedule(damage, building_model, damage_consequences, impedance_options, systems);

%% Determine building functional at each day of the repair schedule
[ functionality.recovery ] = main_functionality( damage, building_model, ...
    damage_consequences, functionality.utilities, subsystems, analysis_options);

%% Save Outputs
if ~exist(outputs_dir,'dir')
    mkdir(outputs_dir)
end
save([outputs_dir filesep 'recovery_outputs.mat','functionality'])
fprintf('Recovery assessment of model %s complete\n',model_name)
