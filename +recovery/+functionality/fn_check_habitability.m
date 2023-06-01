function [ reoccupancy ] = fn_check_habitability( damage, damage_consequences, reoc_meta, func_meta, habitability_requirements )
% Overwrite reocuppancy with additional checks from the functionality check
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage, loss, and repair time data for each 
%   component in the building
% damage_consequences: struct
%   data structure containing simulated building consequences, such as red
%   tags and repair costs ratios
% reoc_meta: struct
%   meta data from reoccupancy assessment
% func_meta: struct
%   meta data from functionality assessment
% habitability_requirements: struct
%   basic requirements for habitability beyond basic reoccupancy.
%
% Returns
% -------
% reoccupancy: struct
%   contains data on the recovery of tenant- and building-level reoccupancy, 
%   recovery trajectorires, and contributions from systems and components 


import recovery.functionality.fn_extract_recovery_metrics

% Functionality checks to adopt onto reoccupancy requirements for
% habitability:
    % heating, cooling, vent, exhaust, potable water, sanitary, electrical
recovery_day = reoc_meta.recovery_day;
comp_breakdowns = reoc_meta.comp_breakdowns;
habitability_list = fieldnames(habitability_requirements);
% habitability_list = {'electrical', 'water_potable', 'water_sanitary', 'hvac_ventilation', 'hvac_heating', 'hvac_cooling', 'hvac_exhaust'};
for i = 1:length(habitability_list)
    if habitability_requirements.(habitability_list{i}) % If this system is required for habitability
        recovery_day.habitability.(habitability_list{i}) = func_meta.recovery_day.tenant_function.(habitability_list{i});
        comp_breakdowns.habitability.(habitability_list{i}) = func_meta.comp_breakdowns.tenant_function.(habitability_list{i});
    end
end

% Go through each of the tenant function branches and combines checks
day_tentant_unit_reoccupiable = 0;
fault_tree_events_LV1 = fieldnames(comp_breakdowns);
for i = 1:length(fault_tree_events_LV1)
    fault_tree_events_LV2 = fieldnames(comp_breakdowns.(fault_tree_events_LV1{i}));
    for j = 1:length(fault_tree_events_LV2)
        day_tentant_unit_reoccupiable = max(day_tentant_unit_reoccupiable,...
            recovery_day.(fault_tree_events_LV1{i}).(fault_tree_events_LV2{j}));
    end
end

% Reformat outputs into reoccupancy data strucutre
[ reoccupancy ] = fn_extract_recovery_metrics( day_tentant_unit_reoccupiable, ...
    recovery_day, comp_breakdowns, damage.comp_ds_table.comp_id', ...
    damage_consequences.simulated_replacement_time );

end

