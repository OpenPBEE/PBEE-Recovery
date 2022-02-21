function [damage, worker_data, building_repair_schedule ] = main_repair_schedule(...
    damage, building_model, simulated_red_tags, repair_time_options, ...
    systems, impeding_factors, surge_factor)
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
% simulated_red_tags: logical array [num_realization x 1]
%   for each realization of the Monte Carlo simulation, is the structure
%   expected to be red-tagged
% repair_time_options: struct
%   general repair time options such as mitigation factors
% systems: table
%   attributes of structural and nonstructural building systems; data 
%   provided in static tables directory
% impeding_factors: struct
%   simulated impedance times
% surge_factor: number
%   amplification factor for temporary repair times due to materials and
%   labor impacts due to regional damage
%
% Returns
% -------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% worker_data: struct
%   simulated building-level worker allocations throught the repair process
% building_repair_schedule: struct
%   simulations of the building repair schedule, broken down by component,
%   story, and system


%% Initial Setup
% Import Packages
import recovery.repair_schedule.*

%% Step 1 - Define max worker allocations
% Define the maximum number of workers that can be on site, based on REDI
max_workers_per_building = ...
    min(max(floor(building_model.total_area_sf * ...
    repair_time_options.max_workers_per_sqft_building + 10), ...
    repair_time_options.max_workers_building_min), ...
    repair_time_options.max_workers_building_max);

% Define the maximum number of workers that can be on any given story,
% based on FEMA P-58
max_workers_per_story = ...
    ceil(building_model.area_per_story_sf * ...
    repair_time_options.max_workers_per_sqft_story); 

%% Step 2 - Calculate the start and finish times for each system in isolation
% based on REDi repair sequencing and Yoo 2016 worker allocations
[ system_schedule ] = fn_calc_system_repair_time(damage, systems, max_workers_per_building, max_workers_per_story);

%% Step 3 - Simulate Temporary Repair Times
[ tmp_repair_complete_day ] = fn_simulate_tmp_repair_times( damage, ...
                              impeding_factors.breakdowns.inspection.complete_day,...
                              repair_time_options.temp_repair_beta, ...
                              surge_factor );
                          
%% Step 4 - Set system repair priority
[ sys_idx_priority_matrix ] = fn_prioritize_systems( systems, damage, tmp_repair_complete_day );
                          
%% Step 5 - Define system repair constraints
[ sys_constraint_matrix ] = fn_set_repair_constraints( systems, simulated_red_tags );

%% Step 6 - Allocate workers among systems and determine the total days until repair is completed for each sequence
[repair_complete_day_per_system, worker_data] = fn_allocate_workers_systems(...
    system_schedule.system_totals.repair_days, system_schedule.system_totals.num_workers, ...
     max_workers_per_building, sys_idx_priority_matrix, sys_constraint_matrix, ...
    simulated_red_tags, impeding_factors.time_sys );
                          
%% Step 7 - Format Outputs 
% Format outputs for Functionality calculations
[ damage ] = fn_restructure_repair_schedule( damage, system_schedule, ...
             repair_complete_day_per_system, systems, tmp_repair_complete_day);

% Format Start and Stop Time Data for Gantt Chart plots 
[ building_repair_schedule ] = fn_format_gantt_chart_data( damage, systems );

end

