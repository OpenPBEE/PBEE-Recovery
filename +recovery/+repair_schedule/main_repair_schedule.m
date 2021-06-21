function [damage, impeding_factors, worker_data, building_repair_schedule ] = main_repair_schedule(...
    damage, building_model, damage_consequences, repair_time_options, systems)
% Determine the repair time for a given damage simulation.
%
% Simulation of system and building level repair times based on a
% simulation of impedance factor and repair scheduling algorithm.
% Simulates the repair times for all realizations of a single ground motion
% or intensity level.
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% building_model: struct
%   data structure containing general information about the building
% damage_consequences: struct
%   data structure containing simulated building consequences, such as red
%   tags and repair costs ratios
% repair_time_options: struct
%   general repair time options such as mitigation factors
% systems: table
%   data table containing information about each system's attributes
%
% Returns
% -------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% impeding_factors: struct
%   simulated impedance times
% worker_data: struct
%   simulated building-level worker allocations throught the repair process
% building_repair_schedule: struct
%   simulations of the building repair schedule, broken down by component,
%   story, and system


%% Initial Setup
% Import Packages
import recovery.repair_schedule.*
import recovery.repair_schedule.impedance.main_impeding_factors

%% Step 1 - Define max worker allocations
% Set the range for max workers per story and on site 
max_workers_per_building = min(max(floor(building_model.total_area_sf*0.00025+10),20),260); % based on REDi
max_workers_per_story = ceil(building_model.area_per_story_sf * 0.001); % based on FEMA P-58

%% Step 2 - Calculate the start and finish times for each system in isolation
% based on REDi repair sequencing and Yoo 2016 worker allocations
[ system_schedule ] = fn_calc_system_repair_time(damage, systems, max_workers_per_building, max_workers_per_story);

%% Step 3 - Simulate impeding factor times
[impeding_factors] = main_impeding_factors(...
    damage, ...   
    repair_time_options, ...
    damage_consequences.repair_cost_ratio, ...
    damage_consequences.inpsection_trigger, ...
    systems, ...
    system_schedule.system_totals.repair_days ...
);

%% Step 4 - Set system repair priority
[ sys_idx_priority_matrix ] = fn_prioritize_systems( systems, damage );

%% Step 5 - Define system repair constraints
[ sys_constraint_matrix ] = fn_set_repair_constraints( systems, damage_consequences.red_tag );

%% Step 6 - Allocate workers among systems and determine the total days until repair is completed for each sequence
[repair_complete_day_per_system, worker_data] = fn_allocate_workers_systems(...
    system_schedule.system_totals.repair_days, system_schedule.system_totals.num_workers, max_workers_per_building, ...
    sys_idx_priority_matrix, sys_constraint_matrix, ...
    damage_consequences.red_tag, impeding_factors.time_sys );

%% Step 7 - Format Outputs 
% Format outputs for Functionality calculations
[ damage ] = fn_restructure_repair_schedule( damage, system_schedule, repair_complete_day_per_system, systems, ...
    damage_consequences.global_fail, building_model.replacement_time_days, repair_time_options.surge_factor );

% Format Start and Stop Time Data for Gantt Chart plots 
[ building_repair_schedule ] = fn_format_gantt_chart_data( damage, systems );

end

