function [ recovery_day, comp_breakdowns ] = fn_tenant_function( damage, ...
    building_model, system_operation_day, utilities, subsystems, ...
    tenant_units, functionality_options )
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
num_units = length(damage.tenant_units);
[num_reals, num_comps] = size(damage.tenant_units{1}.qnt_damaged);
num_stories = building_model.num_stories;

recovery_day.elevators = zeros(num_reals,num_units);
recovery_day.exterior = zeros(num_reals,num_units);
recovery_day.interior = zeros(num_reals,num_units);
recovery_day.water = zeros(num_reals,num_units);
recovery_day.electrical = zeros(num_reals,num_units);
recovery_day.hvac = zeros(num_reals,num_units);

comp_breakdowns.elevators = zeros(num_reals,num_comps,num_units);
comp_breakdowns.water = zeros(num_reals,num_comps,num_units);
comp_breakdowns.electrical = zeros(num_reals,num_comps,num_units);
comp_breakdowns.hvac = zeros(num_reals,num_comps,num_units);

%% Go through each tenant unit, define system level performacne and determine tenant unit recovery time
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
    area_affected_build_all_comps = damage.comp_ds_table.fraction_area_affected' .* building_model.total_area_sf .* damage.tenant_units{tu}.qnt_damaged;
    
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
    
    %% Water and Plumbing System
    if unit.is_water_required
        % determine effect on funciton at this tenant unit
        % any major damage to the branch pipes (small diameter) failes for this tenant unit
        tenant_sys_recovery_day = max(repair_complete_day .* damage.fnc_filters.water_unit,[],2); 
        recovery_day.water(:,tu) = max(system_operation_day.building.water_main,tenant_sys_recovery_day);
        
        % Consider effect of external water network
        utility_repair_day = utilities.water;
        recovery_day.water = max(recovery_day.water,utility_repair_day);
        
        % distribute effect to the components
        comp_breakdowns.water(:,:,tu) = max(system_operation_day.comp.water_main, repair_complete_day .* damage.fnc_filters.water_unit);
    end
    
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
    % HVAC Equipment - Tenant Level
    if unit.is_hvac_required
        % Nonredundant equipment
        % any major damage to the equipment servicing this tenant unit fails the system for this tenant unit
        nonredundant_sys_repair_day = max(repair_complete_day .* damage.fnc_filters.hvac_unit_nonredundant,[],2); 

        % Redundant systems
        % only fail system when a sufficient number of component have failed
        redundant_subsystems = unique(damage.comp_ds_table.subsystem_id(damage.fnc_filters.hvac_unit_redundant));
        redundant_sys_repair_day = zeros(num_reals,1);
        for s = 1:length(redundant_subsystems) % go through each redundant subsystem
            this_redundant_sys = damage.fnc_filters.hvac_unit_redundant & (damage.comp_ds_table.subsystem_id == redundant_subsystems(s))';
            n1_redundancy = max(damage.comp_ds_table.n1_redundancy(this_redundant_sys)); % should all be the same within a subsystem
            
            % go through each component in this subsystem and find number of damaged units
            comps = unique(damage.comp_ds_table.comp_idx(this_redundant_sys));
            num_tot_comps = zeros(1,length(comps));
            num_damaged_comps = zeros(num_reals,length(comps));
            for c = 1:length(comps)
                this_comp = this_redundant_sys & (damage.comp_ds_table.comp_idx' == comps(c));
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
                tenant_subsystem_failure = zeros(num_reals,1);
            elseif subsystem_num_comps == 1 % Not actually redundant
                tenant_subsystem_failure = subsystem_num_damaged_comps == 0;
            elseif n1_redundancy
                % These components are designed to have N+1 redundncy rates,
                % meaning they are designed to lose one component and still operate at
                % normal level
                tenant_subsystem_failure = subsystem_num_damaged_comps > 1;
            else
                % Use a predefined ratio
                tenant_subsystem_failure = ratio_operating < functionality_options.required_ratio_operating_hvac_unit;
            end
            
            % Calculate recovery day and combine with other subsystems for this tenant unit
            % assumes all quantities in each subsystem are repaired at
            % once, which is true for our current repair schedule (ie
            % system level at each story)
            redundant_sys_repair_day = max(redundant_sys_repair_day, ...
                max(tenant_subsystem_failure .*  this_redundant_sys .* repair_complete_day,[],2)); 
        end

        % Combine tenant level equipment with main building level equipment
        tenant_hvac_fnc_recovery_day = max(redundant_sys_repair_day, nonredundant_sys_repair_day); 
        recovery_day.hvac(:,tu) = max(tenant_hvac_fnc_recovery_day,system_operation_day.building.hvac_main);
        
        % distribute the the components affecting function
        % (note these components anytime they cause specific system failure)
        nonredundant_comps_day = damage.fnc_filters.hvac_unit_nonredundant .* initial_damaged .* nonredundant_sys_repair_day;
        redundant_comps_day = damage.fnc_filters.hvac_unit_redundant .* initial_damaged .* redundant_sys_repair_day;
        comp_breakdowns.hvac(:,:,tu) = max(max(nonredundant_comps_day, redundant_comps_day), system_operation_day.comp.hvac_main);

        % HVAC Distribution - Tenant Level - subsystems
        subsystem_handle = {'hvac_duct_braches', 'hvac_in_line_fan', 'hvac_duct_drops', 'hvac_vav_boxes'};
        for sub = 1:length(subsystem_handle)
            if sum(damage.fnc_filters.hvac_duct_braches) > 0
                subsystem_threshold = subsystems.redundancy_threshold(strcmp(subsystems.handle,subsystem_handle{sub}));

                % Assess subsystem recovery day for this tenant unit
                [subsystem_recovery_day, subsystem_comp_recovery_day] = fn_quantify_hvac_subsystem_recovery_day(...
                    damage.fnc_filters.(subsystem_handle{sub}), total_num_comps, repair_complete_day, initial_damaged, ...
                    damaged_comps, subsystem_threshold, damage.comp_ds_table.comp_idx', damage.comp_ds_table.is_sim_ds');

                % Compile with tenant unit performacne and component breakdowns
                recovery_day.hvac(:,tu) = max(recovery_day.hvac(:,tu), subsystem_recovery_day);
                comp_breakdowns.hvac(:,:,tu) = max(comp_breakdowns.hvac(:,:,tu), subsystem_comp_recovery_day);
            end
        end
    end
end

end

function [subsystem_recovery_day, subsystem_comp_recovery_day] = fn_quantify_hvac_subsystem_recovery_day(...
    subsystem_filter, total_num_comps, repair_complete_day, initial_damaged, damaged_comps, subsystem_threshold, pg_id, is_sim_ds)

% Determine the ratio of damaged components that affect system operation
sub_sys_pg_id = unique(pg_id(subsystem_filter));
num_comp = 0;
for c = 1:length(sub_sys_pg_id)
    sub_sys_pg_filt = subsystem_filter & (pg_id == sub_sys_pg_id(c));
    num_comp = num_comp + max(total_num_comps(sub_sys_pg_filt));
end
tot_num_comp_dam = sum(damaged_comps .* subsystem_filter,2); % Assumes damage states are never simultaneous
ratio_damaged = tot_num_comp_dam ./ num_comp;   

% Check to make sure its not simeltanous
% Quantification of number of damaged comp
if any(is_sim_ds(subsystem_filter))
    error('PBEE_Recovery:Function','HVAC Function check does not handle performance groups with simultaneous damage states')
end

% If ratio of component in this subsystem is greater than the
% threshold, the system fails for this tenant unit
subsystem_failure = ratio_damaged > subsystem_threshold;

% Calculate tenant unit recovery day for this subsystem
subsystem_recovery_day = max(subsystem_filter .* subsystem_failure .* repair_complete_day,[],2);

% Distrbute recovery day to the components affecting function for this subsystem
subsystem_comp_recovery_day = subsystem_filter .* initial_damaged .* subsystem_recovery_day;
           
end
