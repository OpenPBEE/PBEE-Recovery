function [ recovery_day, comp_breakdowns ] = fn_tenant_safety( damage, ...
    building_model, functionality_options, tenant_units )
% Check each tenant unit for damage that would cause that tenant unit 
% to be shut down due to issues of locay safety
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage, loss, and repair time data for each 
%   component in the building
% building_model: struct
%   general attributes of the building model
% functionality_options: struct
%   recovery time optional inputs such as various damage thresholds
% tenant_units: table
%   attributes of each tenant unit within the building
%
% Returns
% -------
% recovery_day: struct
%   simulation of the number of days each fault tree event is affecting safety
%   in each tenant unit
% comp_breakdowns: struct
%   simulation of each components contributions to each of the fault tree events 

%% Initial Setup
[num_reals, num_comps] = size(damage.tenant_units{1}.qnt_damaged);
num_units = length(damage.tenant_units);
comp_types_interior_check = unique(damage.comp_ds_table.comp_type_id(damage.fnc_filters.int_fall_haz_all));

% go through each tenant unit and quantify the affect that each system has on reoccpauncy
for tu = 1:num_units
    % Grab tenant and damage info for this tenant unit
    unit = tenant_units(tu,:);
    repair_complete_day_w_tmp = damage.tenant_units{tu}.recovery.repair_complete_day_w_tmp; % day each component (and DS) is reparied of this TU

    %% Exterior Enclosure 
    % Calculated the affected perimeter area of exterior components
    % (assuming all exterior components have either lf or sf units)
    area_affected_all_linear_comps = damage.comp_ds_table.fraction_area_affected' .* damage.comp_ds_table.unit_qty' .* building_model.ht_per_story_ft(tu) .* damage.tenant_units{tu}.qnt_damaged;
    area_affected_all_area_comps = damage.comp_ds_table.fraction_area_affected' .* damage.comp_ds_table.unit_qty' .* damage.tenant_units{tu}.qnt_damaged;
    
    % construct a matrix of affected areas from the various damaged component types
    comp_affected_area = zeros(num_reals,num_comps);
    comp_affected_area(:,damage.fnc_filters.exterior_safety_lf) = area_affected_all_linear_comps(:,damage.fnc_filters.exterior_safety_lf);
    comp_affected_area(:,damage.fnc_filters.exterior_safety_sf) = area_affected_all_area_comps(:,damage.fnc_filters.exterior_safety_sf);
    
    % Go each possible unique repair time contributing to interior safety check
    % Find when enough repairs are complete such that interior damage no
    % longer affects tenant safety
    comps_day_repaired = repair_complete_day_w_tmp; % define as initial repair day considering tmp repairs
    ext_repair_day = zeros(num_reals,1);
    all_comps_day_repaired = zeros(num_reals,num_comps);
    num_repair_time_increments = sum(damage.fnc_filters.exterior_safety_all); % possible unique number of loop increments
    for i = 1:num_repair_time_increments
        
        % Quantify Affected Area
        area_affected = sum(comp_affected_area,2); % Assumes cladding components do not occupy the same perimeter area
        percent_area_affected = area_affected / unit.perim_area;

        % Check if this is sufficent enough to cause as tenant safety issue
        affects_occupancy = percent_area_affected > functionality_options.exterior_safety_threshold;

        % Determine step increment based on the component with the shortest repair time
        delta_day = min(comps_day_repaired(:,damage.fnc_filters.exterior_safety_all),[],2);
        delta_day(isnan(delta_day)) = 0;
        
        % Add increment to the tally of days until the interior damage
        % stops affecting occupancy
        ext_repair_day = ext_repair_day + affects_occupancy .* delta_day;
        
        % Add days to components that are affecting occupancy
        any_area_affected_all_comps = (damage.fnc_filters.exterior_safety_all .* comp_affected_area) > 0; % Count any component that contributes to the loss of occupancy regardless of by how much
        all_comps_day_repaired = all_comps_day_repaired + any_area_affected_all_comps .* affects_occupancy .* delta_day;
        
        % Reduce compent damaged for the next increment based on what was
        % repaired in this increment
        comps_day_repaired = comps_day_repaired - delta_day;
        comps_day_repaired(comps_day_repaired <= 0) = NaN;
        fixed_comps_filt = isnan(comps_day_repaired);
        comp_affected_area(fixed_comps_filt) = 0;
    end
    
    % Save exterior recovery day for this tenant unit
    recovery_day.exterior(:,tu) = ext_repair_day;
    comp_breakdowns.exterior(:,:,tu) = all_comps_day_repaired;
    
    %% Interior Falling Hazards
    % Convert all component into affected areas
    area_affected_all_linear_comps = damage.comp_ds_table.fraction_area_affected' .* damage.comp_ds_table.unit_qty' .* building_model.ht_per_story_ft(tu) .* damage.tenant_units{tu}.qnt_damaged;
    area_affected_all_area_comps   = damage.comp_ds_table.fraction_area_affected' .* damage.comp_ds_table.unit_qty' .* damage.tenant_units{tu}.qnt_damaged;
    area_affected_all_bay_comps    = damage.comp_ds_table.fraction_area_affected' .* building_model.struct_bay_area_per_story(tu) .* damage.tenant_units{tu}.qnt_damaged;
    area_affected_all_build_comps  = damage.comp_ds_table.fraction_area_affected' .* building_model.total_area_sf .* damage.tenant_units{tu}.qnt_damaged;
    
    % Checking damage that affects components in story below
    repair_complete_day_w_tmp_w_instabilities = repair_complete_day_w_tmp;
    if tu > 1
        area_affected_below = damage.comp_ds_table.fraction_area_affected' .* building_model.struct_bay_area_per_story(tu-1) .* damage.tenant_units{tu-1}.qnt_damaged;
        area_affected_all_bay_comps(:,damage.fnc_filters.vert_instabilities) ...
            = max(area_affected_below(:,damage.fnc_filters.vert_instabilities),area_affected_all_bay_comps(:,damage.fnc_filters.vert_instabilities));
        repair_time_below = damage.tenant_units{tu-1}.recovery.repair_complete_day_w_tmp;
        repair_complete_day_w_tmp_w_instabilities(:,damage.fnc_filters.vert_instabilities) ...
            = max(repair_time_below(:,damage.fnc_filters.vert_instabilities),repair_complete_day_w_tmp(:,damage.fnc_filters.vert_instabilities));
    end

    % construct a matrix of affected areas from the various damaged component types
    comp_affected_area = zeros(num_reals,num_comps);
    comp_affected_area(:,damage.fnc_filters.int_fall_haz_lf) = area_affected_all_linear_comps(:,damage.fnc_filters.int_fall_haz_lf);
    comp_affected_area(:,damage.fnc_filters.int_fall_haz_sf) = area_affected_all_area_comps(:,damage.fnc_filters.int_fall_haz_sf);
    comp_affected_area(:,damage.fnc_filters.int_fall_haz_bay) = area_affected_all_bay_comps(:,damage.fnc_filters.int_fall_haz_bay);
    comp_affected_area(:,damage.fnc_filters.int_fall_haz_build) = area_affected_all_build_comps(:,damage.fnc_filters.int_fall_haz_build);
    
    % Go each possible unique repair time contributing to interior safety check
    % Find when enough repairs are complete such that interior damage no
    % longer affects tenant safety
    comps_day_repaired = repair_complete_day_w_tmp_w_instabilities; % define as initial repair day considering tmp repairs
    int_repair_day = zeros(num_reals,1);
    all_comps_day_repaired = zeros(num_reals,num_comps);
    num_repair_time_increments = sum(damage.fnc_filters.int_fall_haz_all); % possible unique number of loop increments
    for i = 1:num_repair_time_increments
        % Quantify Affected Area
        diff_comp_areas = [];
        for cmp = 1:length(comp_types_interior_check)
            filt = strcmp(damage.comp_ds_table.comp_type_id,comp_types_interior_check{cmp})'; % check to see if it matches the first part of the ID (ie the type of comp)
            diff_comp_areas(:,cmp) = sum(comp_affected_area(:,filt),2);
        end
        area_affected = sqrt(sum(diff_comp_areas.^2,2)); % total area affected is the srss of the areas in the unit
        
        % Determine if current damage affects occupancy
        percent_area_affected = min(area_affected / unit.area,1);
        affects_occupancy = percent_area_affected > functionality_options.interior_safety_threshold;
        
        % Determine step increment based on the component with the shortest repair time
        delta_day = min(comps_day_repaired(:,damage.fnc_filters.int_fall_haz_all),[],2);
        delta_day(isnan(delta_day)) = 0;
        
        % Add increment to the tally of days until the interior damage
        % stops affecting occupancy
        int_repair_day = int_repair_day + affects_occupancy .* delta_day;
        
        % Add days to components that are affecting occupancy
        any_area_affected_all_comps = (damage.fnc_filters.int_fall_haz_all .* comp_affected_area) > 0; % Count any component that contributes to the loss of occupancy regardless of by how much
        all_comps_day_repaired = all_comps_day_repaired + any_area_affected_all_comps .* affects_occupancy .* delta_day;
        
        % Reduce compent damaged for the next increment based on what was
        % repaired in this increment
        comps_day_repaired = comps_day_repaired - delta_day;
        comps_day_repaired(comps_day_repaired <= 0) = NaN;
        fixed_comps_filt = isnan(comps_day_repaired);
        comp_affected_area(fixed_comps_filt) = 0;
    end
    
    % Save interior recovery day for this tenant unit
    recovery_day.interior(:,tu) = int_repair_day;
    comp_breakdowns.interior(:,:,tu) = all_comps_day_repaired;
    
    %% Hazardous Materials
    % note: hazardous materials are accounted for in building functional
    % assessment here, but are not currently quantified in the component
    % breakdowns
    if any(damage.fnc_filters.local_hazardous_material)
        % Any local hazardous material shuts down the entire tenant unit
        recovery_day.hazardous_material(:,tu) = max(repair_complete_day_w_tmp(:,damage.fnc_filters.local_hazardous_material),[],2); 
    else
        recovery_day.hazardous_material(:,tu) = zeros(num_reals,1);
    end
end

end % end function

