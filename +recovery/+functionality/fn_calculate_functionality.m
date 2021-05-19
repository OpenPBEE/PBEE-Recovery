function [functionality] = fn_calculate_functionality(damage, damage_consequences, utilities, ...
    building_model, subsystems, reoccupancy, analysis_options )
% Calcualte the loss and recovery of building functionality based on global building
% damage, local component damage, and extenernal factors
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
%   data table containing information about each subsystem's attributes
% reoccupancy: struct
%   contains data on the recovery of tenant- and building-level function, 
%   recovery trajectorires, and contributions from systems and components 
% analysis_options: struct
%   recovery time optional inputs such as various damage thresholds
%
% Returns
% -------
% functionality: struct
%   contains data on the recovery of tenant- and building-level function, 
%   recovery trajectorires, and contributions from systems and components 

%% Initial Set Up
% import packages
import recovery.functionality.*

%% Define the day each system becomes functionl - Building level
[ system_operation_day ] = fn_building_level_system_operation( damage, damage_consequences, ...
    building_model, utilities, analysis_options );

%% Define the day each system becomes functionl - Tenant level
[ recovery_day.tenant_function, comp_breakdowns.tenant_function ] = fn_tenant_function( damage, ...
    building_model, system_operation_day, damage_consequences.global_fail, utilities, subsystems, analysis_options );

%% Combine Checks to determine per unit functionality
% Each tenant unit is functional only if it is occupiable
day_tentant_unit_functional = reoccupancy.tenant_unit.recovery_day;

% Go through each of the tenant function branches and combines checks
fault_tree_events = fieldnames(recovery_day.tenant_function);
for i = 1:length(fault_tree_events)
    day_tentant_unit_functional = max(day_tentant_unit_functional,recovery_day.tenant_function.(fault_tree_events{i}));
end

%% Reformat outputs into functionality data strucutre
[ functionality ] = fn_extract_recovery_metrics( day_tentant_unit_functional, recovery_day, comp_breakdowns, ...
    building_model.replacement_time_days, damage_consequences.global_fail, damage.comp_ds_info.comp_id );

end

