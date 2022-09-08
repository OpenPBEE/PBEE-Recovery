function [functional] = fn_calculate_functionality(damage, damage_consequences, utilities, ...
    building_model, subsystems, reoccupancy, functionality_options, tenant_units )
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
% functionality_options: struct
%   recovery time optional inputs such as various damage thresholds
% tenant_units: table
%   attributes of each tenant unit within the building
%
% Returns
% -------
% functionality: struct
%   contains data on the recovery of tenant- and building-level function, 
%   recovery trajectorires, and contributions from systems and components 

%% Initial Set Up
% import packages
import recovery.functionality.fn_building_level_system_operation
import recovery.functionality.fn_tenant_function
import recovery.functionality.fn_extract_recovery_metrics
import recovery.functionality.fn_combine_comp_breakdown

%% Define the day each system becomes functionl - Building level
[ system_operation_day ] = fn_building_level_system_operation( damage, damage_consequences, ...
    building_model, utilities, functionality_options );

%% Define the day each system becomes functionl - Tenant level
[ recovery_day.tenant_function, comp_breakdowns.tenant_function ] = fn_tenant_function( ...
    damage, building_model, system_operation_day, utilities, subsystems, tenant_units );

%% Combine Checks to determine per unit functionality
% Each tenant unit is functional only if it is occupiable
day_tentant_unit_functional = reoccupancy.tenant_unit.recovery_day;

% Go through each of the tenant function branches and combines checks
fault_tree_events = fieldnames(recovery_day.tenant_function);
for i = 1:length(fault_tree_events)
    day_tentant_unit_functional = max(day_tentant_unit_functional,recovery_day.tenant_function.(fault_tree_events{i}));
end

%% Reformat outputs into functionality data strucutre
[ functional ] = fn_extract_recovery_metrics( day_tentant_unit_functional, ...
    recovery_day, comp_breakdowns, damage.comp_ds_table.comp_id', ...
    damage_consequences.simulated_replacement );

% get the combined component breakdown
functional.breakdowns.component_combined = fn_combine_comp_breakdown( ...
    damage.comp_ds_table, ...
    functional.breakdowns.perform_targ_days, ... % assumes names are consistent in both objects
    functional.breakdowns.comp_names, ...        % assumes names are consistent in both objects
    reoccupancy.breakdowns.component_breakdowns_all_reals, ...
    functional.breakdowns.component_breakdowns_all_reals ...
);

end

