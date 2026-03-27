function [reoccupancy, recovery_day, comp_breakdowns] = fn_calculate_reoccupancy(...
    damage, damage_consequences, utilities, building_model,...
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
% impeding_temp_repairs: struct
%   contains simulated temporary repairs the impede occuapancy and function
%   but are calulated in parallel with the temp repair schedule
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
[ recovery_day.building_safety, comp_breakdowns.building_safety ] = ...
    fn_building_safety( damage, building_model, damage_consequences, ...,
    utilities, functionality_options, impeding_temp_repairs );

%% Stage 2: Quantify the accessibility of each story in the building
[ recovery_day.story_access, comp_breakdowns.story_access ] = ...
    fn_story_access( damage, building_model, damage_consequences, ...
    functionality_options, impeding_temp_repairs );

%% Stage 3: Quantify the effect that component damage has on the safety of each tenant unit
[ recovery_day.tenant_safety, comp_breakdowns.tenant_safety ] = ...
    fn_tenant_safety( damage, building_model, functionality_options, tenant_units );

%% Combine Check to determine the day the each tenant unit is reoccupiable
% Check the day the building is Safe
building_safety_fields = fieldnames(recovery_day.building_safety);
% the old hard coded ones excluded 'falling_hazard' and 'entry_door_racking'
% building_safety_fields = {'red_tag', 'shoring', 'hazardous_material', 'entry_door_access', 'fire_suppression'};  
day_building_safe = 0;

for i_field = 1:length(building_safety_fields)
    building_safety_field = building_safety_fields{i_field};
    day_building_safe = max(day_building_safe, recovery_day.building_safety.(building_safety_field));
end

% Check the day each story is accessible
story_access_fields = fieldnames(recovery_day.story_access);
% story_access_fields = {'stairs', 'stair_doors', 'flooding', 'horizontal_egress'};  % old hard coded ones
day_story_accessible = 0;

for i_field = 1:length(story_access_fields)
    story_access_field = story_access_fields{i_field};
    day_story_accessible = max(day_story_accessible, recovery_day.story_access.(story_access_field));
end

% Check the day each tenant unit is safe
tu_safety_fields = fieldnames(recovery_day.tenant_safety);
% tu_safety_fields = {'interior', 'exterior', 'hazardous_material'};  % old hard coded ones
day_tenant_unit_safe = 0;

for i_field = 1:length(tu_safety_fields)
    tu_safety_field = tu_safety_fields{i_field};
    day_tenant_unit_safe = max(day_tenant_unit_safe, recovery_day.tenant_safety.(tu_safety_field));
end

% Combine checks to determine when each tenant unit is re-occupiable
day_tentant_unit_reoccupiable = max(max(day_building_safe, day_story_accessible), day_tenant_unit_safe); 

%% Reformat outputs into occupancy data strucutre
[ reoccupancy ] = fn_extract_recovery_metrics( day_tentant_unit_reoccupiable, ...
     recovery_day, comp_breakdowns, damage.comp_ds_table.comp_id', ...
     damage_consequences.simulated_replacement_time );


end

