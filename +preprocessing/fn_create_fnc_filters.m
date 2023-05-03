function [ fnc_filters ] = fn_create_fnc_filters( comp_ds_table )
% Define function filter arrays that allow rapid sampling of simulated
% damage for use within the fault tree analysis
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
% fnc_filters: struct of arrays
%   each filter is a 1 x num_comp_ds array that can be used to sample
%   select types of damage from the damage.tenant unit or damage.story
%   simulated damage arrays.
%

%% Impedance filters
fnc_filters.permit_rapid = strcmp(comp_ds_table.permit_type, 'rapid');
fnc_filters.permit_full = strcmp(comp_ds_table.permit_type, 'full');
fnc_filters.redesign = comp_ds_table.redesign == 1;

%% Building level filters
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

% Define when the building requires shoring from external falling hazards
fnc_filters.requires_shoring = logical(comp_ds_table.requires_shoring);

% Define when the building has issues with internal flooding
fnc_filters.causes_flooding = logical(comp_ds_table.causes_flooding);

%% System dependent filters
% fire suppresion system damage that affects entire building
fnc_filters.fire_building = comp_ds_table.system == 9 & strcmp(string(comp_ds_table.service_location),'building') & comp_ds_table.impairs_system_operation;

% fire suppresion damage that affects each tenant unit
fnc_filters.fire_unit = comp_ds_table.system == 9 & ~comp_ds_table.subsystem_id == 23 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation; % pipe and brace branches (not spinkler heads)
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

% Data system
fnc_filters.data_main = comp_ds_table.system == 11 & strcmp(string(comp_ds_table.service_location),'building') & comp_ds_table.impairs_system_operation;
fnc_filters.data_unit = comp_ds_table.system == 11 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation;

% Horizontal Egress: Fire break partitions
fnc_filters.fire_break = comp_ds_table.system == 3 & comp_ds_table.weakens_fire_break; % only collect interior fire break partitions

%% Flip orientation of fnc_filters to match orientation of damage data [reals x ds]
names = fieldnames(fnc_filters);
for fn = 1:length(names)
    tmp_fnc_filt.(names{fn}) = fnc_filters.(names{fn})';
end
fnc_filters = tmp_fnc_filt; % assign to damage data structure

end

