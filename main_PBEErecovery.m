function [functionality, damage_consequences] = main_PBEErecovery(damage, damage_consequences, ...
    building_model, tenant_units, systems, subsystems, tmp_repair_class, ...
    impedance_options, impeding_factor_medians, repair_time_options, ...
    functionality, functionality_options)
% Perform the ATC-138 functional recovery time assessement given similation
% of component damage for a single shaking intensity
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% damage_consequences: struct
%   data structure containing simulated building consequences, such as red
%   tags and repair costs ratios
% building_model: struct
%   general attributes of the building model
% tenant_units: table
%   attributes of each tenant unit within the building
% systems: table
%   data table containing information about each system's attributes
% subsystems: table
%   attributes of building subsystems; data provided in static tables
%   directory
% tmp_repair_class: table
%   data table containing information about each temporary repair class
%   attributes. Attributes are similar to those in the systems table.
% impedance_options: struct
%   general impedance assessment user inputs such as mitigation factors
% impeding_factor_medians: table
%   median delays for various impeding factors
% repair_time_options: struct
%   general repair time options such as mitigation factors
% functionality.utilities
%   data structure containing simulated utility downtimes
% functionality_options: struct
%   recovery time optional inputs such as various damage thresholds
%
%
% Returns
% -------
% functionality: struct
%   contains data on the recovery of tenant- and building-level function, 
%   recovery trajectorires, and contributions from systems and components, 
%   simulated repair schedule breakdowns and impeding times.

%% Import Packages
import preprocessing.main_preprocessing
import recovery.impedance.main_impeding_factors
import recovery.repair_schedule.main_repair_schedule
import recovery.functionality.main_functionality

%% Combine compoment attributes into recovery filters to expidite recovery assessment
[damage, tmp_repair_class, damage_consequences] = main_preprocessing(...
    damage.comp_ds_table, damage, repair_time_options, tmp_repair_class, ...
    damage_consequences, building_model.num_stories);

%% Calculate Red Tags
[ damage_consequences.red_tag, damage_consequences.red_tag_impact, damage_consequences.inspection_trigger ] ...
    = fn_red_tag( functionality_options.calculate_red_tag, damage, building_model.comps,...
    damage_consequences.simulated_replacement_time);

%% Simulate ATC 138 Impeding Factors
[functionality.impeding_factors] = main_impeding_factors(damage, impedance_options, ...
    damage_consequences.repair_cost_ratio_total, damage_consequences.repair_cost_ratio_engineering, ...
    damage_consequences.inspection_trigger, systems, tmp_repair_class, ...
    building_model.building_value, impeding_factor_medians);

%% Construct the Building Repair Schedule
[damage, functionality.worker_data, functionality.building_repair_schedule ] = ...
    main_repair_schedule(damage, building_model, damage_consequences.red_tag, ...
    repair_time_options, systems, tmp_repair_class, ...
    functionality.impeding_factors, damage_consequences.simulated_replacement_time);

%% Calculate the Recovery of Building Reoccupancy and Function
[ functionality.recovery ] = main_functionality( damage, building_model, ...
    damage_consequences, functionality.utilities, functionality_options, ...
    tenant_units, subsystems, functionality.impeding_factors.temp_repair );

end
