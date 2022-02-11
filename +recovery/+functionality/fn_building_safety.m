function [ recovery_day, comp_breakdowns, system_operation_day ] = fn_building_safety( ...
    damage, building_model, damage_consequences, utilities, analysis_options )
% Check damage that would cause the whole building to be shut down due to
% issues of safety
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
% analysis_options: struct
%   recovery time optional inputs such as various damage thresholds
%
% Returns
% -------
% recovery_day: struct
%   simulation of the number of days each fault tree event is affecting building
%   safety
% comp_breakdowns: struct
%   simulation of each components contributions to each of the fault tree events 
% system_operation_day: struct
%   simulation of recovery of operation for various systems in the building

%% Initial Setup
num_reals = length(damage_consequences.red_tag);
num_units = length(damage.tenant_units);
num_comps = length(damage.comp_ds_info.comp_id);

%% Calculate effect of red tags and fire suppression system
% Initialize parameters
recovery_day.red_tag = zeros(num_reals, 1);
recovery_day.hazardous_material = zeros(num_reals, 1);
system_operation_day.building.fire = 0;

% Check damage throughout the building
for tu = 1:num_units
    % Grab tenant and damage info for this tenant unit
    repair_complete_day = damage.tenant_units{tu}.recovery.repair_complete_day;
    
    %% Red Tags
    % The day the red tag is resolved is the day when all damage (anywhere in building) that has
    % the potentail to cause a red tag is fixed (ie max day)
    if any(damage.fnc_filters.red_tag)
        recovery_day.red_tag = max(recovery_day.red_tag, ...
            damage_consequences.red_tag .* max(repair_complete_day(:,damage.fnc_filters.red_tag),[],2)); 
    end
    
    % Componet Breakdowns
    comp_breakdowns.red_tag(:,:,tu) = damage.fnc_filters.red_tag .* recovery_day.red_tag;
    
    %% Day the fire suppression system is operating again (for the whole building)
    if sum(damage.fnc_filters.fire_building) > 0
        % any major damage fails the system for the whole building so take the max
        system_operation_day.building.fire = max(system_operation_day.building.fire,max(repair_complete_day(:,damage.fnc_filters.fire_building),[],2));
    end
    
    % Consider utilities
    system_operation_day.building.fire = max(system_operation_day.building.fire,utilities.water); % Assumes building does not have backup water supply
    
    % Componet Breakdowns
    system_operation_day.comp.fire(:,:,tu) = damage.fnc_filters.fire_building .* repair_complete_day;
    
    %% Hazardous Materials
    % note: hazardous materials are accounted for in building functional
    % assessment here, but are not currently quantified in the component
    % breakdowns
    if any(damage.fnc_filters.global_hazardous_material)
        % Any global hazardous material shuts down the entire building
        recovery_day.hazardous_material = max(recovery_day.hazardous_material, max(repair_complete_day(:,damage.fnc_filters.global_hazardous_material),[],2)); 
    end
    
end

%% Building Egress
% Calculate when falling hazards or racking of doors affects the building
% safety due to limited entrance and exit door access

% Simulate a random location of the doors on two sides of the building for
% each realization. Location is defined at the center of the door as a
% fraction of the building width on that side
door_location = rand(num_reals,building_model.num_entry_doors);

% Assign odd doors to side 1 and even doors to side two
door_numbers = 1:building_model.num_entry_doors;
door_side = ones(1,building_model.num_entry_doors);
door_side(rem(door_numbers, 2) == 0) = 2;

% Determine the quantity of falling hazard damage and when it will be
% resolved
day_repair_fall_haz = zeros(num_reals,building_model.num_entry_doors);
fall_haz_comps_day_rep = zeros(num_reals,num_comps,num_units,building_model.num_entry_doors);
comp_affected_area = zeros(num_reals,num_comps,num_units);
for tu = 1:num_units
    repair_complete_day_w_tmp(:,:,tu) = damage.tenant_units{tu}.recovery.repair_complete_day_w_tmp;
end

% Loop through component repair times to determine the day it stops affecting re-occupancy
num_repair_time_increments = sum(damage.fnc_filters.ext_fall_haz_all)*num_units; % possible unique number of loop increments
edge_lengths = [building_model.edge_lengths,building_model.edge_lengths];
for i = 1:num_repair_time_increments 
    % Calculate the falling hazards per side
    for tu = 1:num_units
        for s = 1:4 % assumes there are 4 sides
            area_affected_lf_all_comps = damage.comp_ds_info.fraction_area_affected .* ...
                damage.comp_ds_info.unit_qty .* building_model.ht_per_story_ft(tu) .* damage.tenant_units{tu}.(['qnt_damaged_side_' num2str(s)]);
            area_affected_sf_all_comps = damage.comp_ds_info.fraction_area_affected .* ...
                damage.comp_ds_info.unit_qty .* damage.tenant_units{tu}.(['qnt_damaged_side_' num2str(s)]);

            comp_affected_area(:,damage.fnc_filters.ext_fall_haz_lf,tu) = area_affected_lf_all_comps(:,damage.fnc_filters.ext_fall_haz_lf);
            comp_affected_area(:,damage.fnc_filters.ext_fall_haz_sf,tu) = area_affected_sf_all_comps(:,damage.fnc_filters.ext_fall_haz_sf);

            comp_affected_ft_this_story = comp_affected_area(:,:,tu) ./ building_model.ht_per_story_ft(tu);
            affected_ft_this_story = sum(comp_affected_ft_this_story,2); % Assumes cladding components do not occupy the same perimeter space

            affected_ratio.(['side_' num2str(s)])(:,tu) = min((affected_ft_this_story) ./ edge_lengths(tu,s),1);
        end
    end

    % Calculate the time increment for this loop
    delta_day = min(min(repair_complete_day_w_tmp(:,damage.fnc_filters.ext_fall_haz_all,:),[],3),[],2);
    delta_day(isnan(delta_day)) = 0;
    if sum(delta_day) == 0
        break % everything has been fixed
    end
    
    % Go through each door to determine which is affected by falling
    % hazards
    for d = 1:building_model.num_entry_doors
        % Combine affected areas of all stories above the first using SRSS
        % HARDCODED ASSUMPTIONS: DOORS ONLY ON TWO SIDES
        fall_haz_zone = min(sqrt(sum(affected_ratio.(['side_' num2str(door_side(d))])(:,2:end) .^2,2)),1);

        % Augment the falling hazard zone with the door access zone
        % add the door access width to the width of falling hazards to account
        % for the width of the door (ie if any part of the door access zone is
        % under the falling hazard, its a problem)
        door_access_zone = analysis_options.door_access_width_ft / building_model.edge_lengths(1,door_side(d)); 
        total_fall_haz_zone = fall_haz_zone + 2*door_access_zone;

        % Determine if current damage affects occupancy
        % if the randonmly simulated door location is with falling hazard zone
        affects_door = door_location(:,door_side(d)) < total_fall_haz_zone;

        % Add days in this increment to the tally
        day_repair_fall_haz(:,d) = day_repair_fall_haz(:,d) + affects_door .* delta_day;

        % Add days to components that are affecting occupancy
        fall_haz_comps_day_rep(:,:,:,d) = fall_haz_comps_day_rep(:,:,:,d) + comp_affected_area .* damage.fnc_filters.ext_fall_haz_all .* affects_door .* delta_day;
    end
    
    % Change the comps for the next increment
    repair_complete_day_w_tmp = repair_complete_day_w_tmp - delta_day;
    repair_complete_day_w_tmp(repair_complete_day_w_tmp <= 0) = NaN;
end

% Determine when racked doors are resolved
day_repair_racked = zeros(num_reals, building_model.num_entry_doors);
side_1_count = 0;
side_2_count = 0;
for d = 1:building_model.num_entry_doors
    if door_side(d) == 1
        side_1_count = side_1_count + 1;
        day_repair_racked(:,d) = analysis_options.door_racking_repair_day * (damage_consequences.racked_entry_doors_side_1 >= side_1_count);
    else 
        side_2_count = side_2_count + 1;
        day_repair_racked(:,d) = analysis_options.door_racking_repair_day * (damage_consequences.racked_entry_doors_side_2 >= side_2_count);
    end
end
door_access_day = max(day_repair_racked,day_repair_fall_haz);

% Find the days until door egress is regained from resolution of both
% falling hazards or door racking
cum_days = 0;
recovery_day.entry_door_access = zeros(num_reals,1);
door_access_day_nan = door_access_day;
door_access_day_nan(door_access_day_nan == 0) = NaN;
num_repair_time_increments = building_model.num_entry_doors; % possible unique number of loop increments
for i = 1:num_repair_time_increments
    num_accessible_doors = sum(door_access_day <= cum_days,2);
    sufficent_door_access_with_fs  = num_accessible_doors >= max(1,analysis_options.egress_threshold*building_model.num_entry_doors);   % must have at least 1 functioning entry door or 50% of design egress
    sufficent_door_access_wo_fs = num_accessible_doors >= max(1,analysis_options.egress_threshold_wo_fs*building_model.num_entry_doors);  % must have at least 1 functioning entry door or 75% of design egress when fire suppression system is down
    fire_system_failure = system_operation_day.building.fire > cum_days;
    entry_door_accessible = sufficent_door_access_with_fs .* ~fire_system_failure + sufficent_door_access_wo_fs .* fire_system_failure;
    
    if i == 1 % just save on the initial loop
        fs_operation_matters_for_entry_doors = sufficent_door_access_with_fs - sufficent_door_access_wo_fs;
    end
            
    delta_day = min(door_access_day_nan,[],2);
    delta_day(isnan(delta_day)) = 0;
    door_access_day_nan = door_access_day_nan - delta_day;
    cum_days = cum_days + delta_day;
    
    recovery_day.entry_door_access = recovery_day.entry_door_access + delta_day .* ~entry_door_accessible;
end

% Determine when Exterior Falling Hazards or doors actually contribute to re-occupancy
recovery_day.falling_hazard = min(recovery_day.entry_door_access,max(day_repair_fall_haz,[],2));
recovery_day.entry_door_racking = min(recovery_day.entry_door_access,max(day_repair_racked,[],2));

% Component Breakdown
comp_breakdowns.falling_hazard = min(recovery_day.entry_door_access,max(fall_haz_comps_day_rep,[],4));

%% Determine when fire suppresion affects recovery
if any(damage.fnc_filters.fire_building) % only safe this when fire system exists
    recovery_day.fire_egress = system_operation_day.building.fire .* fs_operation_matters_for_entry_doors;
    comp_breakdowns.fire_egress = system_operation_day.comp.fire .* fs_operation_matters_for_entry_doors;
end

end

