function [fnc_filters] = fn_preprocessing(comp_ds_table)
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
fnc_filters.fire_drops = comp_ds_table.subsystem_id == 23;

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

% Water and Plumbing
fnc_filters.water_main = comp_ds_table.system == 6 & strcmp(string(comp_ds_table.service_location),'building') & comp_ds_table.impairs_system_operation;
fnc_filters.water_unit = comp_ds_table.system == 6 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation; 

% HVAC
hvac_equip = comp_ds_table.system == 8 & ismember(comp_ds_table.subsystem_id,[15,16,17,18,19,20]);
fnc_filters.hvac_main = hvac_equip & strcmp(string(comp_ds_table.service_location),'building') & comp_ds_table.impairs_system_operation;
fnc_filters.hvac_main_nonredundant = fnc_filters.hvac_main & ~comp_ds_table.parallel_operation;
fnc_filters.hvac_main_redundant = fnc_filters.hvac_main & comp_ds_table.parallel_operation;
fnc_filters.hvac_duct_mains = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 4 & strcmp(string(comp_ds_table.service_location),'building') & comp_ds_table.impairs_system_operation;
fnc_filters.hvac_cooling_piping = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 11 & comp_ds_table.impairs_system_operation;
fnc_filters.hvac_heating_piping = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 10 & comp_ds_table.impairs_system_operation;
fnc_filters.hvac_unit = hvac_equip & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation;
fnc_filters.hvac_unit_nonredundant = fnc_filters.hvac_unit & ~comp_ds_table.parallel_operation;
fnc_filters.hvac_unit_redundant = fnc_filters.hvac_unit & comp_ds_table.parallel_operation;
fnc_filters.hvac_duct_braches = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 4 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation;
fnc_filters.hvac_in_line_fan = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 5 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation; 
fnc_filters.hvac_duct_drops = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 6 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation;
fnc_filters.hvac_vav_boxes = comp_ds_table.system == 8 & comp_ds_table.subsystem_id == 7 & strcmp(string(comp_ds_table.service_location),'unit') & comp_ds_table.impairs_system_operation;
fnc_filters.hvac_mcs = comp_ds_table.system == 8 & comp_ds_table.impairs_system_operation & comp_ds_table.subsystem_id == 2;


%% Flip orientation of fnc_filters to match orientation of damage data [reals x ds]
names = fieldnames(fnc_filters);
for fn = 1:length(names)
    tmp_fnc_filt.(names{fn}) = fnc_filters.(names{fn})';
end
fnc_filters = tmp_fnc_filt;

end