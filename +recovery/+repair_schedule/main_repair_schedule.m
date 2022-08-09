function [damage, worker_data, building_repair_schedule ] = main_repair_schedule(...
    damage, building_model, simulated_red_tags, repair_time_options, ...
    systems, tmp_repair_class, impeding_factors, simulated_replacement)
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
% tmp_repair_class: table
%   data table containing information about each temporary repair class
%   attributes. Attributes are similar to those in the systems table.
% impeding_factors: struct
%   simulated impedance times
% simulated_replacement: array [num_reals x 1]
%   simulated time when the building needs to be replaced, and how long it
%   will take (in days). NaN represents no replacement needed (ie
%   building will be repaired)
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

% Define the maximum number of workers that can be on site, based on REDI
max_workers_per_building = ...
    min(max(floor(building_model.total_area_sf * ...
    repair_time_options.max_workers_per_sqft_building + 10), ...
    repair_time_options.max_workers_building_min), ...
    repair_time_options.max_workers_building_max);
                          
%% Determine repair schedule per system for Temporary Repairs 
% Define the maximum number of workers that can be on any given story
max_workers_per_story = ...
    ceil(building_model.area_per_story_sf * ...
    repair_time_options.max_workers_per_sqft_story_temp_repair); 

% Temporary Repairs
repair_type = 'temp';
[tmp_damage, tmp_worker_data] = fn_schedule_repairs(...
    damage, repair_type, tmp_repair_class, max_workers_per_building, ...
    max_workers_per_story, impeding_factors.temp_repair, simulated_red_tags, []);

% Calculate the max temp repair complete day for each component (anywhere
% in building)
tmp_repair_complete_day = nan(size(damage.tenant_units{1}.tmp_worker_day));
% NaN = Never damaged
% Inf  = Damage not resolved by temp repair
for tu = 1:length(tmp_damage.tenant_units)
    tmp_repair_complete_day = ...
        max(tmp_repair_complete_day,...
            tmp_damage.tenant_units{tu}.recovery.repair_complete_day);
end

%% Determine repair schedule per system for Full Repairs 
% Define the maximum number of workers that can be on any given story
max_workers_per_story = ...
    ceil(building_model.area_per_story_sf * ...
    repair_time_options.max_workers_per_sqft_story); 

% Full Repairs
repair_type = 'full';
[damage, worker_data] = fn_schedule_repairs(...
    damage, repair_type, systems, max_workers_per_building, max_workers_per_story,...
    impeding_factors, simulated_red_tags, tmp_repair_complete_day);

%% Combine temp and full repair schedules
for tu = 1:length(tmp_damage.tenant_units)
    % Repair time is the lesser of the full repair and temp repair times
    damage.tenant_units{tu}.recovery.repair_complete_day_w_tmp = ...
        min(damage.tenant_units{tu}.recovery.repair_complete_day,...
            tmp_damage.tenant_units{tu}.recovery.repair_complete_day);
    % Temporary Repair Times control if temporary repair times are less
    % than the full repair time
    tmp_day_controls = tmp_damage.tenant_units{tu}.recovery.repair_complete_day < ...
        damage.tenant_units{tu}.recovery.repair_complete_day;
    % Repair start day is set to the temp repair start day when temp
    % repairs control
    damage.tenant_units{tu}.recovery.repair_start_day_w_tmp = damage.tenant_units{tu}.recovery.repair_start_day;
    damage.tenant_units{tu}.recovery.repair_start_day_w_tmp(tmp_day_controls) = ...
        tmp_damage.tenant_units{tu}.recovery.repair_start_day(tmp_day_controls);
end

%% Format Outputs 
% Format Start and Stop Time Data for Gantt Chart plots 
% This is also the main data structure used for calculating full repair time
% outputs
[ building_repair_schedule ] = fn_format_gantt_chart_data( damage, systems, simulated_replacement );

end



function [damage, worker_data] = ...
    fn_schedule_repairs(damage, repair_type, systems, max_workers_per_building, max_workers_per_story,...
    impeding_factors, simulated_red_tags, tmp_repair_complete_day)

    %% Initial Setup
    % Import Packages
    import recovery.repair_schedule.*

    %% Step 1 - Calculate the start and finish times for each system in isolation
    % based on REDi repair sequencing and Yoo 2016 worker allocations
    [ system_schedule ] = fn_calc_system_repair_time(damage, repair_type, systems, max_workers_per_building, max_workers_per_story);

    %% Step 2 - Set system repair priority
    [ sys_idx_priority_matrix ] = fn_prioritize_systems( systems, repair_type, damage, tmp_repair_complete_day, impeding_factors );

    %% Step 3 - Define system repair constraints
    [ sys_constraint_matrix ] = fn_set_repair_constraints( systems, repair_type, simulated_red_tags );

    %% Step 4 - Allocate workers among systems and determine the total days until repair is completed for each sequence
    [repair_complete_day_per_system, worker_data] = fn_allocate_workers_systems(...
        systems, system_schedule.system_totals.repair_days, ...
        system_schedule.system_totals.num_workers, max_workers_per_building, ...
        sys_idx_priority_matrix, sys_constraint_matrix, simulated_red_tags, ...
        impeding_factors.time_sys );
    
    %% Step 5 - Format outputs for Functionality calculations
    [ damage ] = fn_restructure_repair_schedule( damage, system_schedule, ...
                 repair_complete_day_per_system, systems, repair_type, simulated_red_tags);

end