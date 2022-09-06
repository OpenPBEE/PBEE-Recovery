function [damage] = fn_preprocessing(comp_ds_table, damage)
% Calculate ATC-138 impeding times for each system given simulation of damage
%
% Parameters
% ----------
% comp_ds_table: table
%   various component attributes by damage state for each component 
%   within the performance model. Can be populated from the 
%   component_attribites.csv and damage_state_attribute_mapping.csv 
%   databases in the static_tables directory.  Each row of the table 
%   corresponds to each column of the simulated component damage arrays 
%   within damage.tenant_units.
%
% Returns
% -------
% fnc_filters: struct
%   logical filters controlling the function and reoccupancy 
%   consequences of various component damage states. Primarily used to
%   expidite the assessment in the functionality module. Each field is a 
%   [1xn] array where n represents the damage state of each component 
%   populated in the builing and corresponding to the columns of the 
%   simulated component damage arrays within damage.tenant_units.


%% Combine compoment attributes into recovery filters to expidite recovery assessment
% combine all damage state filters that have the potential to affect
% function or reoccupancy, other than structural safety damage (for repair
% prioritization)
fnc_filters.affects_reoccupancy = comp_ds_table.affects_envelope_safety | ...
                                  comp_ds_table.ext_falling_hazard | ...
                                  comp_ds_table.int_falling_hazard | ...
                                  comp_ds_table.global_hazardous_material | ...
                                  comp_ds_table.local_hazardous_material | ...
                                  comp_ds_table.affects_access; 
                              
fnc_filters.affects_function = fnc_filters.affects_reoccupancy | ...
                               comp_ds_table.damages_envelope_seal | ...
                               comp_ds_table.obstructs_interior_space | ...
                               comp_ds_table.impairs_system_operation; 

% Define when building has resolved its red tag (when all repairs are complete that may affect red tags)
% get any components that have the potential to cause red tag
fnc_filters.red_tag = comp_ds_table.safety_class > 0; 

% fire suppresion system damage that affects entire building
fnc_filters.fire_building = comp_ds_table.system == 9 & strcmp(string(comp_ds_table.service_location),'building') & comp_ds_table.impairs_system_operation;

% fire suppresion damage that affects each tenant unit
fnc_filters.fire_drops = comp_ds_table.subsystem_id == 23 & comp_ds_table.impairs_system_operation;

% Hazardous materials
fnc_filters.global_hazardous_material = comp_ds_table.global_hazardous_material;
fnc_filters.local_hazardous_material = comp_ds_table.local_hazardous_material;

% Stairs
fnc_filters.stairs = comp_ds_table.affects_access & comp_ds_table.system == 4;

% Exterior enclosure damage
fnc_filters.exterior_safety_lf = strcmp(string(comp_ds_table.unit),'lf') & comp_ds_table.affects_envelope_safety; % Components with perimeter linear feet units
fnc_filters.exterior_safety_sf = strcmp(string(comp_ds_table.unit),'sf') & comp_ds_table.affects_envelope_safety; % Components with perimeter square feet units
fnc_filters.exterior_safety_all = fnc_filters.exterior_safety_lf | fnc_filters.exterior_safety_sf;

% Exterior Falling hazards
fnc_filters.ext_fall_haz_lf = strcmp(string(comp_ds_table.unit),'lf') & comp_ds_table.ext_falling_hazard; % Components with perimeter linear feet units
fnc_filters.ext_fall_haz_sf = strcmp(string(comp_ds_table.unit),'sf') & comp_ds_table.ext_falling_hazard; % Components with perimeter square feet units
fnc_filters.ext_fall_haz_all = fnc_filters.ext_fall_haz_lf | fnc_filters.ext_fall_haz_sf;

% Exterior enclosure envelope seal damage
fnc_filters.exterior_seal_lf = strcmp(string(comp_ds_table.unit),'lf') & comp_ds_table.damages_envelope_seal; % Components with perimeter linear feet units
fnc_filters.exterior_seal_sf = strcmp(string(comp_ds_table.unit),'sf') & comp_ds_table.damages_envelope_seal; % Components with perimeter square feet units
fnc_filters.exterior_seal_all = fnc_filters.exterior_seal_lf | fnc_filters.exterior_seal_sf;

% Roofing components
fnc_filters.roof_structure =       comp_ds_table.subsystem_id == 21 & comp_ds_table.damages_envelope_seal;
fnc_filters.roof_weatherproofing = comp_ds_table.subsystem_id == 22 & comp_ds_table.damages_envelope_seal;

% Interior falling hazards
fnc_filters.int_fall_haz_lf = comp_ds_table.int_falling_hazard & strcmp(string(comp_ds_table.unit),'lf'); % Interior components with perimeter feet units
fnc_filters.int_fall_haz_sf = comp_ds_table.int_falling_hazard & (strcmp(string(comp_ds_table.unit),'sf') | strcmp(comp_ds_table.unit,'each')); % Interior components with area feet units (or each, which is just lights, which we take care of with the fraction affected area, which is probably not the best way to do it)
fnc_filters.int_fall_haz_bay = comp_ds_table.int_falling_hazard & strcmp(string(comp_ds_table.area_affected_unit),'bay'); % structural damage that does not cause red tags but affects function
fnc_filters.int_fall_haz_build = comp_ds_table.int_falling_hazard & strcmp(string(comp_ds_table.area_affected_unit),'building'); % structural damage that does not cause red tags but affects funciton (this one should only be tilt-ups)
fnc_filters.int_fall_haz_all = fnc_filters.int_fall_haz_lf | fnc_filters.int_fall_haz_sf | fnc_filters.int_fall_haz_bay | fnc_filters.int_fall_haz_build; 
fnc_filters.vert_instabilities = comp_ds_table.system == 1 & comp_ds_table.int_falling_hazard; % Flag structural damage that causes interior falling hazards

% Interior function damage 
fnc_filters.interior_function_lf = comp_ds_table.obstructs_interior_space & strcmp(string(comp_ds_table.unit),'lf'); 
fnc_filters.interior_function_sf = comp_ds_table.obstructs_interior_space & (strcmp(string(comp_ds_table.unit),'sf') | strcmp(comp_ds_table.unit,'each'));  
fnc_filters.interior_function_bay = comp_ds_table.obstructs_interior_space & strcmp(string(comp_ds_table.area_affected_unit),'bay') ;
fnc_filters.interior_function_build = comp_ds_table.obstructs_interior_space & strcmp(string(comp_ds_table.area_affected_unit),'building');  
fnc_filters.interior_function_all = fnc_filters.interior_function_lf | ...
                                           fnc_filters.interior_function_sf | ...
                                           fnc_filters.interior_function_bay | ...
                                           fnc_filters.interior_function_build;  

% Elevators
fnc_filters.elevators    = comp_ds_table.system == 5 & comp_ds_table.impairs_system_operation & comp_ds_table.subsystem_id ~= 2;
fnc_filters.elevator_mcs = comp_ds_table.system == 5 & comp_ds_table.impairs_system_operation & comp_ds_table.subsystem_id == 2;

% Electrical system
fnc_filters.electrical_main = comp_ds_table.system == 7 & comp_ds_table.subsystem_id == 1 & strcmp(string(comp_ds_table.service_location),'building') & comp_ds_table.impairs_system_operation;
fnc_filters.electrical_unit = comp_ds_table.system == 7 & comp_ds_table.subsystem_id == 1 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation;

% Potable Water Plumbing
fnc_filters.water_main = comp_ds_table.system == 6 & comp_ds_table.subsystem_id == 8 & strcmp(string(comp_ds_table.service_location),'building') & comp_ds_table.impairs_system_operation;
fnc_filters.water_unit = comp_ds_table.system == 6 & comp_ds_table.subsystem_id == 8 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation; 

% Sanitary Plumbing
fnc_filters.sewer_main = comp_ds_table.system == 6 & comp_ds_table.subsystem_id == 9 & strcmp(string(comp_ds_table.service_location),'building') & comp_ds_table.impairs_system_operation;
fnc_filters.sewer_unit = comp_ds_table.system == 6 & comp_ds_table.subsystem_id == 9 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation; 

% HVAC: Control System
fnc_filters.hvac.building.hvac_control.mcs = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 2 & comp_ds_table.impairs_system_operation;
fnc_filters.hvac.building.hvac_control.control_panel = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 20 & comp_ds_table.impairs_system_operation ;

% HVAC: Ventilation
fnc_filters.hvac.tenant.hvac_ventilation.duct_mains = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 24 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation;
fnc_filters.hvac.tenant.hvac_ventilation.duct_braches = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 4 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation;
fnc_filters.hvac.tenant.hvac_ventilation.in_line_fan = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 5 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation; 
fnc_filters.hvac.tenant.hvac_ventilation.duct_drops = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 6 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation;
fnc_filters.hvac.tenant.hvac_ventilation.ahu = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 19 & comp_ds_table.impairs_system_operation;
fnc_filters.hvac.tenant.hvac_ventilation.rtu = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 17 & comp_ds_table.impairs_system_operation;

% HVAC: Heating
fnc_filters.hvac.building.hvac_heating.piping = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 10 & comp_ds_table.impairs_system_operation; 
fnc_filters.hvac.tenant.hvac_heating.vav = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 7 & comp_ds_table.impairs_system_operation; 

% HVAC: Cooling
fnc_filters.hvac.building.hvac_cooling.piping = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 11 & comp_ds_table.impairs_system_operation; 
fnc_filters.hvac.building.hvac_cooling.chiller = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 15 & comp_ds_table.impairs_system_operation; 
fnc_filters.hvac.building.hvac_cooling.cooling_tower = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 16 & comp_ds_table.impairs_system_operation; 
fnc_filters.hvac.tenant.hvac_cooling.vav = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 7 & comp_ds_table.impairs_system_operation; 

% HVAC: Exhaust
fnc_filters.hvac.tenant.hvac_exhaust.exhaust_fan = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 18 & comp_ds_table.impairs_system_operation;

%% Flip orientation of fnc_filters to match orientation of damage data [reals x ds]
names = fieldnames(fnc_filters);
for fn = 1:length(names)
    tmp_fnc_filt.(names{fn}) = fnc_filters.(names{fn})';
end
damage.fnc_filters = tmp_fnc_filt; % assign to damage data structure

%% Simulate Temporary Repair Times for each component
% In a perfect system this should be done alongside the other full repair
% time simulation. However, I didnt want to add that burden on the user to
% provide more inputs than they are already and compromise the backward
% compatability of the code

% Find total number of damamged components
total_damaged = damage.tenant_units{1}.qnt_damaged;
for tu = 2:length(damage.tenant_units)
    total_damaged = total_damaged + damage.tenant_units{tu}.qnt_damaged;
end

% Aggregate the total number of damaged components accross each damage
% state in a component
tmp_worker_days_per_unit = [];
for c = 1:height(comp_ds_table) % for each comp ds
    comp = comp_ds_table(c,:);
    if comp.tmp_repair_class > 0 % For damage that has temporary repair
        filt = strcmp(comp_ds_table.comp_id,comp.comp_id)';
        total_damaged_all_ds = sum(total_damaged(:,filt),2);

        % Interpolate to get per unit temp repair times
        tmp_worker_days_per_unit(:,c) = ...
            interp1([comp.tmp_repair_time_lower_qnty, comp.tmp_repair_time_upper_qnty],...
                    [comp.tmp_repair_time_lower,comp.tmp_repair_time_upper],...
                    min(max(total_damaged_all_ds,comp.tmp_repair_time_lower_qnty),comp.tmp_repair_time_upper_qnty));
            
    else
        tmp_worker_days_per_unit(:,c) = NaN(size(total_damaged(:,1)));
    end
end

% Simulate uncertainty in per unit temp repair times
% Assumes distribution is lognormal with beta = 0.4
% Assumes time to repair all of a given component group is fully correlated, 
% but independant between component groups 
sim_tmp_worker_days_per_unit = lognrnd(log(tmp_worker_days_per_unit),0.4,size(tmp_worker_days_per_unit));

% Allocate per unit temp repair time among tenant units to calc worker days
% for each component
for tu = 1:length(damage.tenant_units)
    damage.tenant_units{tu}.tmp_worker_day = ...
        damage.tenant_units{tu}.qnt_damaged .* sim_tmp_worker_days_per_unit;
end

end