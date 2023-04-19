function [ recovery_day, comp_breakdowns ] = fn_tenant_function( damage, ...
    building_model, system_operation_day, utilities, subsystems, ...
    tenant_units, impeding_temp_repairs, functionality_options )
% Check each tenant unit for damage that would cause that tenant unit 
% to not be functional
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage, loss, and repair time data for each 
%   component in the building
% building_model: struct
%   general attributes of the building model
% system_operation_day.building: struct
%   simulation of the day operation is recovered for various systems at the
%   building level
% system_operation_day.comp: struct
%   simulation number of days each component is affecting building system
%   operations
% utilities: struct
%   data structure containing simulated utility downtimes
% subsystems: table
%   data table containing information about each subsystem's attributes
% tenant_units: table
%   attributes of each tenant unit within the building
% impeding_temp_repairs: struct
%   contains simulated temporary repairs the impede occuapancy and function
%   but are calulated in parallel with the temp repair schedule
% functionality_options: struct
%   recovery time optional inputs such as various damage thresholds
%
% Returns
% -------
% recovery_day: struct
%   simulation of the number of days each fault tree event is affecting
%   function in each tenant unit
% comp_breakdowns: struct
%   simulation of each components contributions to each of the fault tree events 

%% Initial Setup
% Initialize Variables
num_units = length(damage.tenant_units);
[num_reals, num_comps] = size(damage.tenant_units{1}.qnt_damaged);
num_stories = building_model.num_stories;
recovery_day.elevators = zeros(num_reals,num_units);
recovery_day.exterior = zeros(num_reals,num_units);
recovery_day.interior = zeros(num_reals,num_units);
recovery_day.electrical = zeros(num_reals,num_units);
recovery_day.flooding = zeros(num_reals,num_units);
comp_breakdowns.elevators = zeros(num_reals,num_comps,num_units);
comp_breakdowns.electrical = zeros(num_reals,num_comps,num_units);

%% STORY FLOODING
if functionality_options.include_flooding_impact
    for tu = flip(1:num_stories) % Go from top to bottom
        is_damaged = damage.tenant_units{tu}.qnt_damaged > 0;
        flooding_this_story = any(is_damaged(:,damage.fnc_filters.causes_flooding),2); % Any major piping damage causes interior flooding
        flooding_recovery_day = flooding_this_story .* impeding_temp_repairs.flooding_repair_day;

        % Save clean up time per component causing flooding
        comp_breakdowns.flooding(:,:,tu) = damage.fnc_filters.causes_flooding .* is_damaged .* flooding_recovery_day;

        % This story is not accessible if any story above has flooding
        recovery_day.flooding(:,tu) = max([flooding_recovery_day,recovery_day.flooding(:,(tu+1):end)],[],2);
    end
end

%% SYSTEM SPECIFIC CONSEQUENCES
for tu = 1:num_units
    damaged_comps = damage.tenant_units{tu}.qnt_damaged;
    initial_damaged = damaged_comps > 0;
    total_num_comps = damage.tenant_units{tu}.num_comps;
    unit = tenant_units(tu,:);
    repair_complete_day = damage.tenant_units{tu}.recovery.repair_complete_day;
    repair_complete_day_w_tmp = damage.tenant_units{tu}.recovery.repair_complete_day_w_tmp;
    
    %% Elevators
    if unit.is_elevator_required
        comps_day_repaired = system_operation_day.comp.elev_day_repaired;
        comps_day_repaired(comps_day_repaired == 0) = NaN;
        comps_quant_damaged = system_operation_day.comp.elev_quant_damaged;
        elev_function_recovery_day = zeros(num_reals,1);
        elev_comps_day_fnc = zeros(num_reals,num_comps);
        num_repair_time_increments = sum(damage.fnc_filters.elevators); % possible unique number of loop increments
        % Loop through each unique repair time increment and determine when
        % stops affecting function
        for i = 1:num_repair_time_increments
            % Take the max of component damage to determine the number of
            % shafts/cabs that are damaged/non_operational
            % This assumes that different elevator components are correlated
            num_damaged_elevs = max(comps_quant_damaged,[],2); % this assumes elevators are in one performance group if simeltaneous
            num_damaged_elevs = min(num_damaged_elevs,building_model.num_elevators); % you can never have more elevators damaged than exist
            
            % If elevators are in mutliple performance groups and those
            % elevators have simultaneous damage states, it is not possible
            % to count the number of damaged elevators without additional
            % information
            num_elev_pgs = length(unique(damage.comp_ds_table.comp_idx(damage.fnc_filters.elevators)));
            is_sim_ds = any(damage.comp_ds_table.is_sim_ds(damage.fnc_filters.elevators)');
            if (num_elev_pgs > 1) && is_sim_ds
                error('PBEE_Recovery:Function','Elevator Function check does not handle multiple performance groups with simultaneous damage states')
            end

            % quantifty the number of occupancy needing to use the elevators
            % all occupants above the first floor will try to use the elevators
            building_occ_per_elev = sum(building_model.occupants_per_story(2:end)) ./ (building_model.num_elevators - num_damaged_elevs); 
            
            % elevator function check
            % do tenants have sufficient elevator access need based on
            % elevators that are still operational
            affects_function = building_occ_per_elev > max(unit.occ_per_elev);

            % Add days in this increment to the tally
            delta_day = min(comps_day_repaired(:,damage.fnc_filters.elevators),[],2);
            delta_day(isnan(delta_day)) = 0;
            elev_function_recovery_day = elev_function_recovery_day + affects_function .* delta_day;
            
            % Add days to components that are affecting occupancy
            any_elev_damage = comps_quant_damaged > 0; % Count any component that contributes to the loss of function regardless of by how much 
            elev_comps_day_fnc = elev_comps_day_fnc + any_elev_damage .* affects_function .* delta_day;

            % Change the comps for the next increment
            comps_day_repaired = comps_day_repaired - delta_day;
            comps_day_repaired(comps_day_repaired <= 0) = NaN;
            fixed_comps_filt = isnan(comps_day_repaired);
            comps_quant_damaged(fixed_comps_filt) = 0;
        end
        power_supply_recovery_day = max(max(system_operation_day.building.elevator_mcs,system_operation_day.building.electrical_main),utilities.electrical);
        recovery_day.elevators(:,tu) = max(elev_function_recovery_day,power_supply_recovery_day); % electrical system and utility
        power_supply_recovery_day_comp = max(system_operation_day.comp.elevator_mcs,system_operation_day.comp.electrical_main);
        comp_breakdowns.elevators(:,:,tu) = max(elev_comps_day_fnc,power_supply_recovery_day_comp);
    end
    
    %% Exterior Enclosure 
    % Perimeter Cladding (assuming all exterior components have either lf or sf units)
    area_affected_lf_all_comps = damage.comp_ds_table.fraction_area_affected' .* damage.comp_ds_table.unit_qty' .* building_model.ht_per_story_ft(tu) .* damage.tenant_units{tu}.qnt_damaged;
    area_affected_sf_all_comps = damage.comp_ds_table.fraction_area_affected' .* damage.comp_ds_table.unit_qty' .* damage.tenant_units{tu}.qnt_damaged;
   
    comp_affected_area = zeros(num_reals,num_comps);
    comp_affected_area(:,damage.fnc_filters.exterior_seal_lf) = area_affected_lf_all_comps(:,damage.fnc_filters.exterior_seal_lf);
    comp_affected_area(:,damage.fnc_filters.exterior_seal_sf) = area_affected_sf_all_comps(:,damage.fnc_filters.exterior_seal_sf);
    
    comps_day_repaired = repair_complete_day;
    ext_function_recovery_day = zeros(num_reals,1);
    all_comps_day_ext = zeros(num_reals,num_comps);
    num_repair_time_increments = sum(damage.fnc_filters.exterior_seal_all); % possible unique number of loop increments
    % Loop through each unique repair time increment and determine when stops affecting function
    for i = 1:num_repair_time_increments
        % Determine the area of wall which has severe exterior encolusure damage 
        area_affected = sum(comp_affected_area,2); % Assumes cladding components do not occupy the same perimeter area
        percent_area_affected = min(area_affected / unit.perim_area,1); % normalize it
        
        % Determine if current damage affects function for this tenant unit
        % if the area of exterior wall damage is greater than what is
        % acceptable by the tenant 
        affects_function = percent_area_affected > unit.exterior; 
        
        % Add days in this increment to the tally
        delta_day = min(comps_day_repaired(:,damage.fnc_filters.exterior_seal_all),[],2);
        delta_day(isnan(delta_day)) = 0;
        ext_function_recovery_day = ext_function_recovery_day + affects_function .* delta_day;
        
        % Add days to components that are affecting occupancy
        any_area_affected_all_comps = comp_affected_area > 0; % Count any component that contributes to the loss of occupance regardless of by how much
        all_comps_day_ext = all_comps_day_ext + any_area_affected_all_comps .* affects_function .* delta_day;
        
        % Change the comps for the next increment
        % reducing damage for what has been repaired in this time increment
        comps_day_repaired = comps_day_repaired - delta_day;
        comps_day_repaired(comps_day_repaired <= 0) = NaN;
        fixed_comps_filt = isnan(comps_day_repaired);
        comp_affected_area(fixed_comps_filt) = 0;
    end
    
    if unit.story == num_stories % If this is the top story, check the roof for functio
        % Roof structure (currently assuming all roofing components have equal unit
        % areas)
        damage_threshold = subsystems.redundancy_threshold(subsystems.id == 21);
        num_comp_damaged = damage.fnc_filters.roof_structure .* damage.tenant_units{tu}.qnt_damaged;
        num_roof_comps = damage.fnc_filters.roof_structure .* damage.tenant_units{tu}.num_comps;

        comps_day_repaired = repair_complete_day_w_tmp;
        roof_structure_recovery_day = zeros(num_reals,1);
        all_comps_day_roof_struct = zeros(num_reals,num_comps);
        num_repair_time_increments = sum(damage.fnc_filters.roof_structure); % possible unique number of loop increments
        % Loop through each unique repair time increment and determine when stops affecting function
        for i = 1:num_repair_time_increments
            % Determine the area of roof affected 
            percent_area_affected = sum(num_comp_damaged,2) / sum(num_roof_comps,2); % Assumes roof components do not occupy the same area of roof

            % Determine if current damage affects function for this tenant unit
            % if the area of exterior wall damage is greater than what is
            % acceptable by the tenant 
            affects_function = percent_area_affected >= damage_threshold; 

            % Add days in this increment to the tally
            delta_day = min(comps_day_repaired(:,damage.fnc_filters.roof_structure),[],2);
            delta_day(isnan(delta_day)) = 0;
            roof_structure_recovery_day = roof_structure_recovery_day + affects_function .* delta_day;

            % Add days to components that are affecting function
            any_area_affected_all_comps = num_comp_damaged > 0; % Count any component that contributes to the loss of function regardless of by how much
            all_comps_day_roof_struct = all_comps_day_roof_struct + any_area_affected_all_comps .* affects_function .* delta_day;

            % Change the comps for the next increment
            % reducing damage for what has been repaired in this time increment
            comps_day_repaired = comps_day_repaired - delta_day;
            comps_day_repaired(comps_day_repaired <= 0) = NaN;
            fixed_comps_filt = isnan(comps_day_repaired);
            num_comp_damaged(fixed_comps_filt) = 0;
        end

        % Roof weatherproofing (currently assuming all roofing components have 
        % equal unit areas)
        damage_threshold = subsystems.redundancy_threshold(subsystems.id == 22);
        num_comp_damaged = damage.fnc_filters.roof_weatherproofing .* damage.tenant_units{tu}.qnt_damaged;
        num_roof_comps = damage.fnc_filters.roof_weatherproofing .* damage.tenant_units{tu}.num_comps;

        comps_day_repaired = repair_complete_day_w_tmp;
        roof_weather_recovery_day = zeros(num_reals,1);
        all_comps_day_roof_weather = zeros(num_reals,num_comps);
        num_repair_time_increments = sum(damage.fnc_filters.roof_weatherproofing); % possible unique number of loop increments
        % Loop through each unique repair time increment and determine when stops affecting function
        for i = 1:num_repair_time_increments
            % Determine the area of roof affected 
            percent_area_affected = sum(num_comp_damaged,2) / sum(num_roof_comps,2); % Assumes roof components do not occupy the same area of roof

            % Determine if current damage affects function for this tenant unit
            % if the area of exterior wall damage is greater than what is
            % acceptable by the tenant 
            affects_function = percent_area_affected >= damage_threshold; 

            % Add days in this increment to the tally
            delta_day = min(comps_day_repaired(:,damage.fnc_filters.roof_weatherproofing),[],2);
            delta_day(isnan(delta_day)) = 0;
            roof_weather_recovery_day = roof_weather_recovery_day + affects_function .* delta_day;

            % Add days to components that are affecting function
            any_area_affected_all_comps = num_comp_damaged > 0; % Count any component that contributes to the loss of function regardless of by how much
            all_comps_day_roof_weather = all_comps_day_roof_weather + any_area_affected_all_comps .* affects_function .* delta_day;

            % Change the comps for the next increment
            % reducing damage for what has been repaired in this time increment
            comps_day_repaired = comps_day_repaired - delta_day;
            comps_day_repaired(comps_day_repaired <= 0) = NaN;
            fixed_comps_filt = isnan(comps_day_repaired);
            num_comp_damaged(fixed_comps_filt) = 0;
        end

        % Combine branches
        recovery_day.exterior(:,tu) = max(ext_function_recovery_day,...
            max(roof_structure_recovery_day,roof_weather_recovery_day));
        comp_breakdowns.exterior(:,:,tu) = max(all_comps_day_ext,...
            max(all_comps_day_roof_struct,all_comps_day_roof_weather));
    else % this is not the top story so just use the cladding for tenant function
        recovery_day.exterior(:,tu) = ext_function_recovery_day;
        comp_breakdowns.exterior(:,:,tu) = all_comps_day_ext;
    end
    
    %% Interior Area
    area_affected_lf_all_comps    = damage.comp_ds_table.fraction_area_affected' .* damage.comp_ds_table.unit_qty' .* building_model.ht_per_story_ft(tu) .* damage.tenant_units{tu}.qnt_damaged;
    area_affected_sf_all_comps    = damage.comp_ds_table.fraction_area_affected' .* damage.comp_ds_table.unit_qty' .* damage.tenant_units{tu}.qnt_damaged;
    area_affected_bay_all_comps   = damage.comp_ds_table.fraction_area_affected' .* building_model.struct_bay_area_per_story(tu) .* damage.tenant_units{tu}.qnt_damaged;
    area_affected_build_all_comps = damage.comp_ds_table.fraction_area_affected' .* sum(building_model.area_per_story_sf) .* damage.tenant_units{tu}.qnt_damaged;
    
    repair_complete_day_w_tmp_w_instabilities = repair_complete_day_w_tmp;
    if tu > 1
        area_affected_below = damage.comp_ds_table.fraction_area_affected' .* building_model.struct_bay_area_per_story(tu-1) .* damage.tenant_units{tu-1}.qnt_damaged;
        area_affected_bay_all_comps(:,damage.fnc_filters.vert_instabilities) ...
            = max(area_affected_below(:,damage.fnc_filters.vert_instabilities),area_affected_bay_all_comps(:,damage.fnc_filters.vert_instabilities));
        repair_time_below = damage.tenant_units{tu-1}.recovery.repair_complete_day_w_tmp;
        repair_complete_day_w_tmp_w_instabilities(:,damage.fnc_filters.vert_instabilities) ...
            = max(repair_time_below(:,damage.fnc_filters.vert_instabilities),repair_complete_day_w_tmp(:,damage.fnc_filters.vert_instabilities));
    end

    comp_affected_area = zeros(num_reals,num_comps);
    comp_affected_area(:,damage.fnc_filters.interior_function_lf) = area_affected_lf_all_comps(:,damage.fnc_filters.interior_function_lf);
    comp_affected_area(:,damage.fnc_filters.interior_function_sf) = area_affected_sf_all_comps(:,damage.fnc_filters.interior_function_sf);
    comp_affected_area(:,damage.fnc_filters.interior_function_bay) = area_affected_bay_all_comps(:,damage.fnc_filters.interior_function_bay);
    comp_affected_area(:,damage.fnc_filters.interior_function_build) = area_affected_build_all_comps(:,damage.fnc_filters.interior_function_build);

    frag_types_in_check = unique(damage.comp_ds_table.comp_type_id(damage.fnc_filters.interior_function_all));
    comps_day_repaired = repair_complete_day_w_tmp_w_instabilities;

    int_function_recovery_day = zeros(num_reals,1);
    int_comps_day_repaired = zeros(num_reals,num_comps);
    num_repair_time_increments = sum(damage.fnc_filters.interior_function_all); % possible unique number of loop increments
    % Loop through each unique repair time increment and determine when stops affecting function
    for i = 1:num_repair_time_increments
        % Quantify the affected area (based on srss of differenct component
        % types)
        diff_comp_areas = [];
        for cmp = 1:length(frag_types_in_check)
            filt = strcmp(damage.comp_ds_table.comp_type_id,frag_types_in_check{cmp})'; % check to see if it matches the first part of the ID (ie the type of comp)
            diff_comp_areas(:,cmp) = sum(comp_affected_area(:,filt),2);
        end
        area_affected = sqrt(sum(diff_comp_areas.^2,2)); % total area affected is the srss of the areas in the unit
        percent_area_affected = min(area_affected / unit.area, 1); % no greater than the total unit area
    
        % Determine if current damage affects function for this tenant unit
        % affects function if the area of interior damage is greater than what is
        % acceptable by the tenant 
        affects_function = percent_area_affected > unit.interior; 
        
        % Add days in this increment to the tally
        delta_day = min(comps_day_repaired(:,damage.fnc_filters.interior_function_all),[],2);
        delta_day(isnan(delta_day)) = 0;
        int_function_recovery_day = int_function_recovery_day + affects_function .* delta_day;
        
        % Add days to components that are affecting occupancy
        any_area_affected_all_comps = comp_affected_area > 0; % Count any component that contributes to the loss of occupance regardless of by how much
        int_comps_day_repaired = int_comps_day_repaired + any_area_affected_all_comps .* affects_function .* delta_day;
        
        % Change the comps for the next increment
        % reducing damage for what has been repaired in this time increment
        comps_day_repaired = comps_day_repaired - delta_day;
        comps_day_repaired(comps_day_repaired <= 0) = NaN;
        fixed_comps_filt = isnan(comps_day_repaired);
        comp_affected_area(fixed_comps_filt) = 0;
    end
    recovery_day.interior(:,tu) = int_function_recovery_day;
    comp_breakdowns.interior(:,:,tu) = int_comps_day_repaired;
    
    %% Potable Water System
    % determine effect on funciton at this tenant unit
    % any major damage to the branch pipes (small diameter) failes for this tenant unit
    tenant_sys_recovery_day = max(repair_complete_day .* damage.fnc_filters.water_unit,[],2); 
    recovery_day.water_potable(:,tu) = max(system_operation_day.building.water_potable_main,tenant_sys_recovery_day);

    % distribute effect to the components
    comp_breakdowns.water_potable(:,:,tu) = max(system_operation_day.comp.water_potable_main, repair_complete_day .* damage.fnc_filters.water_unit);
    
    %% Sanitary Waste System
    % determine effect on funciton at this tenant unit
    % any major damage to the branch pipes (small diameter) failes for this tenant unit
    tenant_sys_recovery_day = max(repair_complete_day .* damage.fnc_filters.sewer_unit,[],2); 
    recovery_day.water_sanitary(:,tu) = max(system_operation_day.building.water_sanitary_main,tenant_sys_recovery_day);

    % distribute effect to the components
    comp_breakdowns.water_sanitary(:,:,tu) = max(system_operation_day.comp.water_sanitary_main, repair_complete_day .* damage.fnc_filters.sewer_unit);

    % Sanitary waste operation at this tenant unit depends on the 
    % operation of the potable water system at this tenant unit
    recovery_day.water_sanitary(:,tu) = max(recovery_day.water_sanitary(:,tu),recovery_day.water_potable(:,tu));
    comp_breakdowns.water_sanitary(:,:,tu) = max(comp_breakdowns.water_sanitary(:,:,tu), comp_breakdowns.water_potable(:,:,tu));
    
    %% Electrical Power System
    % Does not consider effect of backup systems
    if unit.is_electrical_required
        % determine effect on funciton at this tenant unit
        % any major damage to the unit level electrical equipment failes for this tenant unit
        tenant_sys_recovery_day = max(repair_complete_day .* damage.fnc_filters.electrical_unit,[],2);
        recovery_day.electrical(:,tu) = max(system_operation_day.building.electrical_main,tenant_sys_recovery_day);
        
        % Consider effect of external water network
        utility_repair_day = utilities.electrical;
        recovery_day.electrical = max(recovery_day.electrical,utility_repair_day);
        
        % distribute effect to the components
        comp_breakdowns.electrical(:,:,tu) = max(system_operation_day.comp.electrical_main, repair_complete_day .* damage.fnc_filters.electrical_unit);
    end
    
    %% HVAC System
    % HVAC: Control System
    recovery_day_hvac_control = system_operation_day.building.hvac_control;
    comp_breakdowns_hvac_control = system_operation_day.comp.hvac_control;

    % HVAC: Ventilation
    dependancy.recovery_day = recovery_day_hvac_control;
    dependancy.comp_breakdown = comp_breakdowns_hvac_control;
    [recovery_day.hvac_ventilation(:,tu), comp_breakdowns.hvac_ventilation(:,:,tu)] = ...
        subsystem_recovery('hvac_ventilation', damage, repair_complete_day, ...
                     total_num_comps, damaged_comps, initial_damaged, dependancy);

    % HVAC: Heating
    dependancy.recovery_day = max(recovery_day.hvac_ventilation(:,tu),system_operation_day.building.hvac_heating);
    dependancy.comp_breakdown = max(comp_breakdowns.hvac_ventilation(:,:,tu),system_operation_day.comp.hvac_heating);
    [recovery_day.hvac_heating(:,tu), comp_breakdowns.hvac_heating(:,:,tu)] = ...
        subsystem_recovery('hvac_heating', damage, repair_complete_day, ...
                     total_num_comps, damaged_comps, initial_damaged, dependancy);

    % HVAC: Cooling
    dependancy.recovery_day = max(recovery_day.hvac_ventilation(:,tu),system_operation_day.building.hvac_cooling);
    dependancy.comp_breakdown = max(comp_breakdowns.hvac_ventilation(:,:,tu),system_operation_day.comp.hvac_cooling);
    [recovery_day.hvac_cooling(:,tu), comp_breakdowns.hvac_cooling(:,:,tu)] = ...
        subsystem_recovery('hvac_cooling', damage, repair_complete_day, ...
                     total_num_comps, damaged_comps, initial_damaged, dependancy);

    % HVAC: Exhast
    dependancy.recovery_day = recovery_day_hvac_control;
    dependancy.comp_breakdown = comp_breakdowns_hvac_control;
    [recovery_day.hvac_exhaust(:,tu), comp_breakdowns.hvac_exhaust(:,:,tu)] = ...
        subsystem_recovery('hvac_exhaust', damage, repair_complete_day, ...
                     total_num_comps, damaged_comps, initial_damaged, dependancy);
                 
    %% Data
    if unit.is_data_required
        % determine effect on funciton at this tenant unit
        % any major damage to the unit level electrical equipment failes for this tenant unit
        tenant_sys_recovery_day = max(repair_complete_day .* damage.fnc_filters.data_unit,[],2);
        recovery_day.data(:,tu) = max(system_operation_day.building.data_main,tenant_sys_recovery_day);
        
        % Consider effect of external water network
        power_supply_recovery_day = max(system_operation_day.building.electrical_main,utilities.electrical);
        recovery_day.data = max(recovery_day.data,power_supply_recovery_day);
        
        % distribute effect to the components
        comp_breakdowns.data(:,:,tu) = max(system_operation_day.comp.data_main, repair_complete_day .* damage.fnc_filters.data_unit);
    end      
                 
    %% Post process for tenant-specific requirements 
    % Zero out systems that are not required by the tenant
    % Still need to calculate above due to dependancies between options
    if ~unit.is_water_potable_required
        recovery_day.water_potable = zeros(num_reals,num_units);
        comp_breakdowns.water_potable = zeros(num_reals,num_comps,num_units);
    end
    if ~unit.is_water_sanitary_required
        recovery_day.water_sanitary = zeros(num_reals,num_units);
        comp_breakdowns.water_sanitary = zeros(num_reals,num_comps,num_units);
    end
    if ~unit.is_hvac_ventilation_required
        recovery_day.hvac_ventilation = zeros(num_reals,num_units);
        comp_breakdowns.hvac_ventilation = zeros(num_reals,num_comps,num_units);
    end
    if ~unit.is_hvac_heating_required
        recovery_day.hvac_heating = zeros(num_reals,num_units);
        comp_breakdowns.hvac_heating = zeros(num_reals,num_comps,num_units);
    end
    if ~unit.is_hvac_cooling_required
        recovery_day.hvac_cooling = zeros(num_reals,num_units);
        comp_breakdowns.hvac_cooling = zeros(num_reals,num_comps,num_units);
    end
    if ~unit.is_hvac_exhaust_required
        recovery_day.hvac_exhaust = zeros(num_reals,num_units);
        comp_breakdowns.hvac_exhaust = zeros(num_reals,num_comps,num_units);
    end
end



end % Function



%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% SUBFUNCTIONS %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%
function [recovery_day_all, comp_breakdowns_all] = subsystem_recovery(...
    subsystem, damage, repair_complete_day, total_num_comps, damaged_comps, ...
    initial_damaged, dependancy)

% import packages
import recovery.functionality.fn_calc_subsystem_recovery

% Set variables
recovery_day_all = dependancy.recovery_day;
comp_breakdowns_all = dependancy.comp_breakdown;

% Go through each component group in this subsystem and determine recovery
% based on impact of system operation at the tenant unit level
subs = fieldnames(damage.fnc_filters.hvac.tenant.(subsystem));
for b = 1:length(subs)
    filt = damage.fnc_filters.hvac.tenant.(subsystem).(subs{b})';
    [recovery_day] = fn_calc_subsystem_recovery( filt, damage, repair_complete_day, total_num_comps, damaged_comps );
    comps_breakdown = filt .* initial_damaged .* recovery_day;
    recovery_day_all = max(recovery_day_all,recovery_day); % combine with previous stories
    comp_breakdowns_all = max(comp_breakdowns_all,comps_breakdown);
end

end % Function
