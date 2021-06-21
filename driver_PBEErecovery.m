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

% Update data with new naming scheme
repair_time_options.functionality = analysis_options;
clear analysis_options

repair_time_options.include_impedance = impedance_options.include_impedance;
repair_time_options.mitigation.is_essential_facility = impedance_options.mitigation.is_essential_facility;
repair_time_options.mitigation.is_borp_equivalent = impedance_options.mitigation.is_borp_equivalent;
repair_time_options.mitigation.is_engineer_on_retainer = impedance_options.mitigation.is_engineer_on_retainer;
repair_time_options.mitigation.is_contractor_on_retainer = impedance_options.mitigation.is_contractor_on_retainer;
repair_time_options.mitigation.funding_source = impedance_options.mitigation.funding_source;
repair_time_options.mitigation.capital_available_ratio = impedance_options.mitigation.capital;
repair_time_options.surge_factor = impedance_options.surge_factor;
clear impedance_options

repair_time_options.tenant_units = building_model.tenant_unit;
building_model = rmfield(building_model,'tenant_unit');
repair_time_options.tenant_units.max_walkable_story = repair_time_options.tenant_units.elevator_story;
repair_time_options.tenant_units.is_elevator_required = repair_time_options.tenant_units.story > repair_time_options.tenant_units.elevator_story;
repair_time_options.tenant_units.is_electrical_required = repair_time_options.tenant_units.electrical;
repair_time_options.tenant_units.is_water_required = repair_time_options.tenant_units.water;
repair_time_options.tenant_units.is_hvac_required = repair_time_options.tenant_units.hvac;

repair_time_options.tenant_units.elevator_story = [];
repair_time_options.tenant_units.electrical = [];
repair_time_options.tenant_units.water = [];
repair_time_options.tenant_units.hvac = [];

save([model_dir filesep model_name filesep 'simulated_inputs.mat'],...
    'building_model','damage','damage_consequences','functionality','repair_time_options')

%% Load system and subsystem data
systems = readtable(['static_tables' filesep 'systems.csv']);
subsystems = readtable(['static_tables' filesep 'subsystems.csv']);

%% Calculate ATC 138 building repair schedule and impeding times
[damage, functionality.impeding_factors, functionality.worker_data, functionality.building_repair_schedule ] = ...
    main_repair_schedule(damage, building_model, damage_consequences, repair_time_options, systems);

%% Determine building functional at each day of the repair schedule
[ functionality.recovery ] = main_functionality( damage, building_model, ...
    damage_consequences, functionality.utilities, subsystems, repair_time_options);

%% Save Outputs
if ~exist(outputs_dir,'dir')
    mkdir(outputs_dir)
end
save([outputs_dir filesep 'recovery_outputs.mat'],'functionality')
fprintf('Recovery assessment of model %s complete\n',model_name)
