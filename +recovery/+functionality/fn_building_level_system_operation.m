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
num_stories = building_model.num_stories;
num_reals = length(damage_consequences.red_tag);
num_comps = length(damage.comp_ds_info.comp_id);

system_operation_day.building.hvac_main = zeros(num_reals,1);

system_operation_day.comp.elev_quant_damaged = zeros(num_reals,num_comps);
system_operation_day.comp.elev_day_repaired = zeros(num_reals,num_comps);
system_operation_day.comp.electrical_main = zeros(num_reals,num_comps);
system_operation_day.comp.water_main = zeros(num_reals,num_comps);
system_operation_day.comp.hvac_main = zeros(num_reals,num_comps);
system_operation_day.comp.elevator_mcs = zeros(num_reals,num_comps);
system_operation_day.comp.hvac_mcs = zeros(num_reals,num_comps);

%% Loop through each story/TU and quantify the building-level performance of each system (e.g. equipment that severs the entire building)
for tu = 1:num_stories
    damaged_comps = damage.tenant_units{tu}.qnt_damaged;
    initial_damaged = damaged_comps > 0;
    total_num_comps = damage.tenant_units{tu}.num_comps;
    repair_complete_day = damage.tenant_units{tu}.recovery.repair_complete_day;
    
    % Elevators
    % Assumed all components affect entire height of shaft
    system_operation_day.comp.elev_quant_damaged = ...
        max(system_operation_day.comp.elev_quant_damaged, damage.tenant_units{tu}.qnt_damaged .* damage.fnc_filters.elevators);
    system_operation_day.comp.elev_day_repaired = ...
        max(system_operation_day.comp.elev_day_repaired, repair_complete_day .* damage.fnc_filters.elevators);
    
    % Electrical
    system_operation_day.comp.electrical_main = ...
        max(system_operation_day.comp.electrical_main, repair_complete_day .* damage.fnc_filters.electrical_main);
    
    % Motor Control system - Elevators
    system_operation_day.comp.elevator_mcs = ...
        max(system_operation_day.comp.elevator_mcs, repair_complete_day .* damage.fnc_filters.elevator_mcs);
    
    % Water
    system_operation_day.comp.water_main = ...
        max(system_operation_day.comp.water_main, repair_complete_day .* damage.fnc_filters.water_main);
    
    % HVAC Equipment and Distribution - Building Level
    % non redundant systems
    main_nonredundant_sys_repair_day = max(repair_complete_day .* damage.fnc_filters.hvac_main_nonredundant,[],2); % any major damage to the nonredundant main building equipment fails the system for the entire building
    
    % Redundant systems
    % only fail system when a sufficient number of component have failed
    redundant_subsystems = unique(damage.comp_ds_info.subsystem_id(damage.fnc_filters.hvac_main_redundant));
    main_redundant_sys_repair_day = zeros(num_reals,1);
    for s = 1:length(redundant_subsystems) % go through each redundant subsystem
        this_redundant_sys = damage.fnc_filters.hvac_main_redundant & (damage.comp_ds_info.subsystem_id == redundant_subsystems(s));
        n1_redundancy = max(damage.comp_ds_info.n1_redundancy(this_redundant_sys)); % should all be the same within a subsystem

        % go through each component in this subsystem and find number of damaged units
        comps = unique(damage.comp_ds_info.comp_idx(this_redundant_sys));
        num_tot_comps = zeros(1,length(comps));
        num_damaged_comps = zeros(num_reals,length(comps));
        for c = 1:length(comps)
            this_comp = this_redundant_sys & (damage.comp_ds_info.comp_idx == comps(c));
            num_tot_comps(c) = max(total_num_comps .* this_comp); % number of units across all ds should be the same
            num_damaged_comps(:,c) = max(damaged_comps .* this_comp,[],2);
        end

        % sum together multiple components in this subsystem
        subsystem_num_comps = sum(num_tot_comps);
        subsystem_num_damaged_comps = sum(num_damaged_comps,2);
        ratio_damaged = subsystem_num_damaged_comps ./ subsystem_num_comps;
        ratio_operating = 1 - ratio_damaged;

        % Check failed component against the ratio of components required for system operation
        % system fails when there is an insufficient number of operating components
        if subsystem_num_comps == 0 % Not components at this level
            subsystem_failure = zeros(num_reals,1);
        elseif subsystem_num_comps == 1 % Not actually redundant
            subsystem_failure = subsystem_num_damaged_comps == 0;
        elseif n1_redundancy
            % These components are designed to have N+1 redundncy rates,
            % meaning they are designed to lose one component and still operate at
            % normal level
            subsystem_failure = subsystem_num_damaged_comps > 1;
        else
            % Use a predefined ratio (default to requirement 2/3 of components operational)
            subsystem_failure = ratio_operating < functionality_options.required_ratio_operating_hvac_main;
        end

        % Calculate recovery day and combine with other subsystems for this tenant unit
        % assumes all quantities in each subsystem are repaired at
        % once, which is true for our current repair schedule (ie
        % system level at each story)
        main_redundant_sys_repair_day = max(main_redundant_sys_repair_day, ...
            max(subsystem_failure .* this_redundant_sys .* repair_complete_day,[],2)); 
    end

    % Ducts
    duct_mains_repair_day = max(repair_complete_day .* damage.fnc_filters.hvac_duct_mains,[],2); % any major damage to the main ducts fails the system for the entire building

    % Cooling piping
    cooling_piping_repair_day = max(repair_complete_day .* damage.fnc_filters.hvac_cooling_piping,[],2); % any major damage to the piping fails the system for the entire building

    % Heating piping
    heating_piping_repair_day = max(repair_complete_day .* damage.fnc_filters.hvac_heating_piping,[],2); % any major damage to the piping fails the system for the entire building

    % HVAC control Equipment
    % hvac control panel is currently embedded into the non-redundant equipment check
    
    % HVAC building level exhaust
    % this is embedded in the main equipment check
    
    % Motor Control system - HVAC
    % if seperate from the hvac control panel (only pulls in if defined as
    % part or the HVAC system -- using the component system attribute)
    hvac_mcs_repair_day = max(repair_complete_day .* damage.fnc_filters.hvac_mcs,[],2); % any major damage fails the system for the whole building so take the max
    
    % Putting it all together
    % Currently not seperating heating equip from cooling equip (as they are currently the same, ie there are no boilers in P-58)
    main_equip_repair_day = max(main_nonredundant_sys_repair_day, main_redundant_sys_repair_day); % This includes hvac controls and exhaust
    heating_utility_repair_day = utilities.gas;
    heating_system_repair_day = max(main_equip_repair_day, max(duct_mains_repair_day, max(heating_utility_repair_day, heating_piping_repair_day)));
    cooling_utility_repair_day = utilities.electrical;
    cooling_system_repair_day = max(main_equip_repair_day, max(duct_mains_repair_day, max(cooling_utility_repair_day, cooling_piping_repair_day)));
    system_operation_day.building.hvac_main = max( system_operation_day.building.hvac_main, ... % combine with damage from previous floors
                                              max( hvac_mcs_repair_day, ...
                                              max( heating_system_repair_day, cooling_system_repair_day))); 

    % HVAC Equipment and Distribution - Building Level
    nonredundant_comps_day = damage.fnc_filters.hvac_main_nonredundant .* initial_damaged .* main_nonredundant_sys_repair_day; % note these components anytime they cause specific system failure
    redundant_comps_day = damage.fnc_filters.hvac_main_redundant .* initial_damaged .* main_redundant_sys_repair_day;
    main_duct_comps_day = damage.fnc_filters.hvac_duct_mains .* initial_damaged .* duct_mains_repair_day;
    cooling_piping_comps_day = damage.fnc_filters.hvac_cooling_piping .* initial_damaged .* cooling_piping_repair_day;
    heating_piping_comps_day = damage.fnc_filters.hvac_heating_piping .* initial_damaged .* heating_piping_repair_day;
    hvac_mcs_comps_day = damage.fnc_filters.hvac_mcs .* initial_damaged .* hvac_mcs_repair_day;
    hvac_comp_recovery_day = max(max(max(max(max(nonredundant_comps_day, redundant_comps_day), ...
                                                 main_duct_comps_day), cooling_piping_comps_day), ...
                                                 heating_piping_comps_day),...
                                                 hvac_mcs_comps_day);
    system_operation_day.comp.hvac_main = max(system_operation_day.comp.hvac_main,hvac_comp_recovery_day);                         
end

%% Calculate building level consequences for systems where any major main damage leads to system failure
system_operation_day.building.electrical_main = max(system_operation_day.comp.electrical_main,[],2);  % any major damage to the main equipment fails the system for the entire building
system_operation_day.building.water_main = max(system_operation_day.comp.water_main,[],2);  % any major damage to the main pipes fails the system for the entire building
system_operation_day.building.elevator_mcs = max(system_operation_day.comp.elevator_mcs,[],2); % any major damage fails the system for the whole building so take the max
system_operation_day.building.hvac_mcs = max(system_operation_day.comp.hvac_mcs,[],2); % any major damage fails the system for the whole building so take the max
end

