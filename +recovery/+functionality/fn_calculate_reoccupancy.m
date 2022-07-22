function [reoccupancy] = fn_calculate_reoccupancy(...
    damage, damage_consequences, utilities, building_model, subsystems,...
    functionality_options, tenant_units, impeding_temp_repairs )
% Calcualte the loss and recovery of building re-occupancy 
% based on global building damage, local component damage, and extenernal factors
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage, loss, and repair time data for each 
%   component in the building
% damage_consequences: struct
%   data structure containing simulated building consequences, such as red
%   tags and repair costs ratios
% utilities: struct
%   data structure containing simulated utility downtimes
% building_model: struct
%   general attributes of the building model
% subsystems: table
%   attributes of building subsystems; data provided in static tables
%   directory
% functionality_options: struct
%   recovery time optional inputs such as various damage thresholds
% tenant_units: table
%   attributes of each tenant unit within the building
%
% Returns
% -------
% reoccupancy: struct
%   contains data on the recovery of tenant- and building-level reoccupancy, 
%   recovery trajectorires, and contributions from systems and components 

%% Initial Set Up
% Import packages
import recovery.functionality.fn_building_safety
import recovery.functionality.fn_story_access
import recovery.functionality.fn_tenant_safety
import recovery.functionality.fn_extract_recovery_metrics
    
%% Stage 1: Quantify the effect that component damage has on the building safety
[ recovery_day.building_safety, comp_breakdowns.building_safety, system_operation_day ] = ...
    fn_building_safety( damage, building_model, damage_consequences, ...,
    utilities, functionality_options, impeding_temp_repairs );

%% Stage 2: Quantify the accessibility of each story in the building
[ recovery_day.story_access, comp_breakdowns.story_access ] = ...
    fn_story_access( damage, building_model, damage_consequences, ...
    system_operation_day, subsystems, functionality_options );

%% Stage 3: Quantify the effect that component damage has on the safety of each tenant unit
[ recovery_day.tenant_safety, comp_breakdowns.tenant_safety ] = ...
    fn_tenant_safety( damage, building_model, functionality_options, tenant_units );

%% Combine Check to determine the day the each tenant unit is reoccupiable
% Check the day the building is Safe
day_building_safe = max(recovery_day.building_safety.red_tag, ...
                    max(recovery_day.building_safety.shoring, ...
                    max(recovery_day.building_safety.hazardous_material, ...
                    max(recovery_day.building_safety.entry_door_access, ...
                        recovery_day.building_safety.fire_suppression))));

% Check the day each story is accessible
day_story_accessible = max(recovery_day.story_access.stairs, ...
                       max(recovery_day.story_access.stair_doors, ...
                           recovery_day.story_access.fire_suppression));

% Check the day each tenant unit is safe
day_tenant_unit_safe = max(recovery_day.tenant_safety.interior, max(recovery_day.tenant_safety.exterior, recovery_day.tenant_safety.hazardous_material));

% Combine checks to determine when each tenant unit is re-occupiable
day_tentant_unit_reoccupiable = max(max(day_building_safe, day_story_accessible), day_tenant_unit_safe); 

%% Reformat outputs into occupancy data strucutre
[ reoccupancy ] = fn_extract_recovery_metrics( day_tentant_unit_reoccupiable, ...
     recovery_day, comp_breakdowns, damage.comp_ds_table.comp_id', ...
     damage_consequences.simulated_replacement );


end

