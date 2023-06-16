function [ system_operation_day ] = fn_building_level_system_operation( damage, ...
    damage_consequences, building_model, utilities, functionality_options )
% Calculate the day certain systems recovery building-level opertaions
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage, loss, and repair time data for each 
%   component in the building
% damage_consequences: struct
%   data structure containing simulated building consequences, such as red
%   tags and repair costs ratios
% building_model: struct
%   general attributes of the building model
% utilities: struct
%   data structure containing simulated utility downtimes
% functionality_options: struct
%   recovery time optional inputs such as various damage thresholds
%
% Returns
% -------
% system_operation_day.building: struct
%   simulation of the day operation is recovered for various systems at the
%   building level
% system_operation_day.comp: struct
%   simulation number of days each component is affecting building system
%   operations

%% Initial Setep
% import packages
import recovery.functionality.fn_calc_subsystem_recovery

% Initialize Variables
num_stories = building_model.num_stories;
num_reals = length(damage_consequences.red_tag);
num_comps = height(damage.comp_ds_table);


system_operation_day.comp.elev_quant_damaged = zeros(num_reals,num_comps);
system_operation_day.comp.elev_day_repaired = zeros(num_reals,num_comps);
system_operation_day.comp.electrical_main = zeros(num_reals,num_comps);
system_operation_day.comp.water_potable_main = zeros(num_reals,num_comps);
system_operation_day.comp.water_sanitary_main = zeros(num_reals,num_comps);
system_operation_day.comp.elevator_mcs = zeros(num_reals,num_comps);
system_operation_day.comp.data_main = zeros(num_reals,num_comps);


%% Loop through each story/TU and quantify the building-level performance of each system (e.g. equipment that severs the entire building)
for tu = 1:num_stories
    damaged_comps = damage.tenant_units{tu}.qnt_damaged;
    initial_damaged = damaged_comps > 0;
    total_num_comps = damage.tenant_units{tu}.num_comps;
    repair_complete_day = damage.tenant_units{tu}.recovery.repair_complete_day;
    
    %% Elevators
    % Assumed all components affect entire height of shaft
    system_operation_day.comp.elev_quant_damaged = ...
        max(system_operation_day.comp.elev_quant_damaged, damage.tenant_units{tu}.qnt_damaged .* damage.fnc_filters.elevators);
    system_operation_day.comp.elev_day_repaired = ...
        max(system_operation_day.comp.elev_day_repaired, repair_complete_day .* damage.fnc_filters.elevators);
    
    % Motor Control system - Elevators
    system_operation_day.comp.elevator_mcs = ...
        max(system_operation_day.comp.elevator_mcs, repair_complete_day .* damage.fnc_filters.elevator_mcs);
    
    %% Electrical
    system_operation_day.comp.electrical_main = ...
        max(system_operation_day.comp.electrical_main, repair_complete_day .* damage.fnc_filters.electrical_main);

    %% Water
    % Potable
    system_operation_day.comp.water_potable_main = ...
        max(system_operation_day.comp.water_potable_main, repair_complete_day .* damage.fnc_filters.water_main);
    
    % Sanitary
    system_operation_day.comp.water_sanitary_main = ...
        max(system_operation_day.comp.water_sanitary_main, repair_complete_day .* damage.fnc_filters.sewer_main);
    
    %% HVAC
    building_hvac_subsystems = fieldnames(damage.fnc_filters.hvac.building);
    for s = 1:length(building_hvac_subsystems)
        subsys_label = building_hvac_subsystems{s};
        if not(isfield(system_operation_day, 'building')) ...
                || not(isfield(system_operation_day.building, subsys_label))
            % Initialize variables if not already initialized
            system_operation_day.building.(subsys_label) = zeros(num_reals, 1);
            system_operation_day.comp.(subsys_label) = zeros(num_reals, num_comps);
        end

        % go through each subsystem and calculate how long entire building operation is impaired
        subs = fieldnames(damage.fnc_filters.hvac.building.(subsys_label));
        for b = 1:length(subs)
            filt = damage.fnc_filters.hvac.building.(subsys_label).(subs{b})';
            
            [repair_day] = fn_calc_subsystem_recovery( filt, damage, ...
                 repair_complete_day, total_num_comps, damaged_comps );
            
            comps_breakdown = filt .* initial_damaged .* repair_day;
            
            % combine with previous stories
            system_operation_day.building.(subsys_label) = ...
                max(system_operation_day.building.(subsys_label), repair_day);
            
            system_operation_day.comp.(subsys_label) = ...
                max(system_operation_day.comp.(subsys_label), comps_breakdown);
        end
    end
    
    %% Data
    system_operation_day.comp.data_main = ...
        max(system_operation_day.comp.data_main, repair_complete_day .* damage.fnc_filters.data_main);
end

%% Calculate building level consequences for systems where any major main damage leads to system failure
system_operation_day.building.electrical_main = max(system_operation_day.comp.electrical_main,[],2);  % any major damage to the main equipment fails the system for the entire building
system_operation_day.building.water_potable_main = max(system_operation_day.comp.water_potable_main,[],2);  % any major damage to the main pipes fails the system for the entire building
system_operation_day.building.water_sanitary_main = max(system_operation_day.comp.water_sanitary_main,[],2);  % any major damage to the main pipes fails the system for the entire building
system_operation_day.building.elevator_mcs = max(system_operation_day.comp.elevator_mcs,[],2); % any major damage fails the system for the whole building so take the max
system_operation_day.building.data_main = max(system_operation_day.comp.data_main,[],2);  % any major damage to the main equipment fails the system for the entire building

%% Account for Extermal Utilities impact on system Operation
% Electricity
system_operation_day.building.electrical_main = max(system_operation_day.building.electrical_main,utilities.electrical);

% Potable water
system_operation_day.building.water_potable_main = max(system_operation_day.building.water_potable_main,utilities.water);

% Assume hvac control runs on electricity and heating system runs on gas
system_operation_day.building.hvac_control = max(system_operation_day.building.hvac_control,system_operation_day.building.electrical_main);
system_operation_day.building.hvac_heating = max(system_operation_day.building.hvac_heating,utilities.(functionality_options.heat_utility));

end

