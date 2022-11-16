% This script builds the matlab datafile inputs required for the
% reoccupancy and functional recovery assessment of a building given
% simulated damage.

% Currently, this script will build the inputs data file for an example
% building model. Follow the instructions below to custumize this build
% script for other assessments.

% Instructions
% ----------
% Step 1: Place this script in the directory where you want the
% simulated_inputs.mat assessment inputs file to be written
% Step 2: Add the requried building specific input files listed below to
% the same directory
% Step 3: Copy the optional_inputs.m file from the example inputs directory
% to the same directory and modify if needed.
% Step 4: Make sure the variable "static_data_dir" is correctly pointing to
% the location of the static data directory
% Step 5: Run the build script

% Option for customizing static data 
% ----------
% If you would like to modify the static data tables listed below for a 
% specifc model, simply copy the subsequent static data tables to this 
% input directory, modify them, and set the static_data_dir to this input 
% directory.

% Required building specific data (inputs directory)
% ----------
% building_model.json
% tenant_unit_list.csv
% comp_ds_list.csv
% damage_consequences.json
% simulated_damage.json

% Optional building specific data (inputs directory)
% ----------
% utility_downtime.json

% Static data (static data directory)
% ----------
% component_attributes.csv
% damage_state_attribute_mapping.csv
% subsystems.csv
% tenant_function_requirements.csv

% Static data (copy to this inputs directory)
% ----------
% optional_inputs.m

clear
close all
clc 
rehash

%% DEFINE USER INPUTS
% This is currently set to the default directory, relative to this example
% inputs directory. If the location of this directory differs, updat the 
% static_data_dir variable below. 
static_data_dir = ['..' filesep '..' filesep '..' filesep 'static_tables'];

%% LOAD BUILDING DATA
% This data is specific to the building model and will need to be created
% for each assessment. Data is formated as json structures or csv tables

% Building Model: Basic data about the building being assessed
building_model = jsondecode(fileread('building_model.json'));

% Transponse building model inputs to go from vertically oriented story
% data to horizontally oriented
names = fieldnames(building_model);
for fn = 1:length(names)
    building_model.(names{fn}) = building_model.(names{fn})';
end

% Translate edge length back to vertically oriented (2 sides) for single
% story buildings
if building_model.num_stories == 1
    building_model.edge_lengths = building_model.edge_lengths';
end

% List of tenant units within the building and their basic attributes
tenant_unit_list = readtable('tenant_unit_list.csv');

% List of component and damage states in the performance model
comp_ds_list = readtable('comp_ds_list.csv');

%% LOAD SIMULATED DATA
% This data is specific to the building performance at the assessed hazard
% intensity and will need to be created for each assessment. 
% Data is formated as json structures.

% Simulated damage consequences - various building and story level
% consequences of simulated data, for each realization of the monte carlo
% simulation.
damage_consequences = jsondecode(fileread('damage_consequences.json'));

% Simulated utility downtimes for electrical, water, and gas networks - 
% for each realization of the monte carlo simulation.
if exist('utility_downtime.json','file')
    functionality = jsondecode(fileread('utility_downtime.json'));
else
    % If no data exist, assume there is no consequence of network downtime
    num_reals = length(damage_consequences.red_tag);
    functionality.utilities.electrical = zeros(num_reals,1);
    functionality.utilities.water = zeros(num_reals,1);
    functionality.utilities.gas = zeros(num_reals,1);
end

% Simulated replacement cases
% assumes all realizations will be repaired
damage_consequences.simulated_replacement = nan(size(damage_consequences.red_tag));

% Simulated component damage per tenant unit for each realization of the
% monte carlo simulation
sim_tenant_unit_damage = jsondecode(fileread('simulated_damage.json'));

% Transform structural array to cell array to work with later code
for tu = 1:length(sim_tenant_unit_damage)
    damage.tenant_units{tu} = sim_tenant_unit_damage(tu);
    damage.tenant_units{tu}.num_comps = damage.tenant_units{tu}.num_comps';
end

%% LOAD DEFAULT OPTIONAL INPUTS
% various assessment otpions. Set to default options in the
% optional_inputs.m file. This file is expected to be in this input
% directory. This file can be customized for each assessment if desired.
optional_inputs

%% PULL ADDITIONAL ATTRIBUTES FROM THE STATIC DATA TABLES
% Load required data tables
component_attributes = readtable([static_data_dir filesep 'component_attributes.csv']);
damage_state_attribute_mapping = readtable([static_data_dir filesep 'damage_state_attribute_mapping.csv']);
subsystems = readtable([static_data_dir filesep 'subsystems.csv']);
tenant_function_requirements = readtable([static_data_dir filesep 'tenant_function_requirements.csv']);

% Preallocate tenant unit table
tenant_units = tenant_unit_list;
tenant_units.exterior = zeros(height(tenant_units),1);
tenant_units.interior = zeros(height(tenant_units),1);
tenant_units.occ_per_elev = zeros(height(tenant_units),1);
tenant_units.is_elevator_required = zeros(height(tenant_units),1);
tenant_units.is_electrical_required = zeros(height(tenant_units),1);
tenant_units.is_water_potable_required = zeros(height(tenant_units),1);
tenant_units.is_water_sanitary_required = zeros(height(tenant_units),1);
tenant_units.is_hvac_ventilation_required = zeros(height(tenant_units),1);
tenant_units.is_hvac_heating_required = zeros(height(tenant_units),1);
tenant_units.is_hvac_cooling_required = zeros(height(tenant_units),1);
tenant_units.is_hvac_exhaust_required = zeros(height(tenant_units),1);

% Pull default tenant unit attributes for each tenant unit listed in the
% tenant_unit_list
for tu = 1:height(tenant_unit_list)
    fnc_requirements_filt = tenant_function_requirements.occupancy_id == tenant_units.occupancy_id(tu);
    if sum(fnc_requirements_filt) ~= 1
        error('Tenant Unit Requirements for This Occupancy Not Found')
    end
    tenant_units.exterior(tu) = tenant_function_requirements.exterior(fnc_requirements_filt);
    tenant_units.interior(tu) = tenant_function_requirements.interior(fnc_requirements_filt);
    tenant_units.occ_per_elev(tu) = tenant_function_requirements.occ_per_elev(fnc_requirements_filt);
    if tenant_function_requirements.is_elevator_required(fnc_requirements_filt) && ...
            tenant_function_requirements.max_walkable_story(fnc_requirements_filt) < tenant_units.story(tu)
        tenant_units.is_elevator_required(tu) = 1;
    else
        tenant_units.is_elevator_required(tu) = 0;
    end
    tenant_units.is_electrical_required(tu) = tenant_function_requirements.is_electrical_required(fnc_requirements_filt);
    tenant_units.is_water_potable_required(tu) = tenant_function_requirements.is_water_potable_required(fnc_requirements_filt);
    tenant_units.is_water_sanitary_required(tu) = tenant_function_requirements.is_water_sanitary_required(fnc_requirements_filt);
    tenant_units.is_hvac_ventilation_required(tu) = tenant_function_requirements.is_hvac_ventilation_required(fnc_requirements_filt);
    tenant_units.is_hvac_heating_required(tu) = tenant_function_requirements.is_hvac_heating_required(fnc_requirements_filt);
    tenant_units.is_hvac_cooling_required(tu) = tenant_function_requirements.is_hvac_cooling_required(fnc_requirements_filt);
    tenant_units.is_hvac_exhaust_required(tu) = tenant_function_requirements.is_hvac_exhaust_required(fnc_requirements_filt);
end


% Pull default component and damage state attributes for each component 
% in the comp_ds_list
comp_idx = 1;
for c = 1:height(comp_ds_list)
    % Basic Component and DS identifiers
    comp_ds_info.comp_id{c,1} = comp_ds_list.comp_id{c};
    comp_ds_info.comp_type_id{c,1} = comp_ds_list.comp_id{c}(1:5); % first 5 characters indicate the type
    if c > 1 && ~strcmp(string(comp_ds_info.comp_id{c}),string(comp_ds_info.comp_id{c-1}))
        % if not the same as the previous component
        comp_idx = comp_idx + 1;
    end
    comp_ds_info.comp_idx(c,1) = comp_idx;
    comp_ds_info.ds_seq_id(c,1) = comp_ds_list.ds_seq_id(c);
    comp_ds_info.ds_sub_id(c,1) = comp_ds_list.ds_sub_id(c);
    
    % Find idx of this component in the  component attribute tables
    comp_attr_filt = strcmp(string(component_attributes.fragility_id),string(comp_ds_info.comp_id{c,1}));
    if sum(comp_attr_filt) ~= 1
        error('Could not find component attrubutes')
    end
    
    % Set Component Attributes
    comp_ds_info.system(c,1) = component_attributes.system_id(comp_attr_filt);
    comp_ds_info.subsystem_id(c,1) = component_attributes.subsystem_id(comp_attr_filt);
    comp_ds_info.unit{c,1} = component_attributes.unit{comp_attr_filt};
    comp_ds_info.unit_qty(c,1) = component_attributes.unit_qty(comp_attr_filt);
    comp_ds_info.service_location{c,1} = component_attributes.service_location{comp_attr_filt};
    
    % Find idx of this damage state in the damage state attribute tables
    ds_comp_filt = ~cellfun(@isempty,regexp(comp_ds_info.comp_id{c,1},damage_state_attribute_mapping.fragility_id_regex));
    ds_seq_filt = damage_state_attribute_mapping.ds_index == comp_ds_info.ds_seq_id(c,1);
    if comp_ds_info.ds_sub_id(c,1) == 1
        % 1 or NA are acceptable for the sub ds
        ds_sub_filt = ismember(damage_state_attribute_mapping.sub_ds_index, {'1', 'NA'});
    else
        ds_sub_filt = ismember(damage_state_attribute_mapping.sub_ds_index, num2str(comp_ds_info.ds_sub_id(c,1)));
    end
    ds_attr_filt = ds_comp_filt & ds_seq_filt & ds_sub_filt;
    if sum(ds_attr_filt) ~= 1
        error('Could not find damage state attrubutes')
    end
    
    % Set Damage State Attributes
    comp_ds_info.is_sim_ds(c,1) = damage_state_attribute_mapping.is_sim_ds(ds_attr_filt);
    comp_ds_info.safety_class(c,1) = damage_state_attribute_mapping.safety_class(ds_attr_filt);
    comp_ds_info.affects_envelope_safety(c,1) = damage_state_attribute_mapping.affects_envelope_safety(ds_attr_filt);
    comp_ds_info.ext_falling_hazard(c,1) = damage_state_attribute_mapping.exterior_falling_hazard(ds_attr_filt);
    comp_ds_info.int_falling_hazard(c,1) = damage_state_attribute_mapping.interior_falling_hazard(ds_attr_filt);
    comp_ds_info.global_hazardous_material(c,1) = damage_state_attribute_mapping.global_hazardous_material(ds_attr_filt);
    comp_ds_info.local_hazardous_material(c,1) = damage_state_attribute_mapping.local_hazardous_material(ds_attr_filt);
    comp_ds_info.affects_access(c,1) = damage_state_attribute_mapping.affects_access(ds_attr_filt);
    comp_ds_info.damages_envelope_seal(c,1) = damage_state_attribute_mapping.damages_envelope_seal(ds_attr_filt);
    comp_ds_info.obstructs_interior_space(c,1) = damage_state_attribute_mapping.obstructs_interior_space(ds_attr_filt);
    comp_ds_info.impairs_system_operation(c,1) = damage_state_attribute_mapping.impairs_system_operation(ds_attr_filt);
    comp_ds_info.fraction_area_affected(c,1) = damage_state_attribute_mapping.fraction_area_affected(ds_attr_filt);
    comp_ds_info.area_affected_unit(c,1) = damage_state_attribute_mapping.area_affected_unit(ds_attr_filt);
    comp_ds_info.crew_size(c,1) = damage_state_attribute_mapping.crew_size(ds_attr_filt);
    comp_ds_info.permit_type(c,1) = damage_state_attribute_mapping.permit_type(ds_attr_filt);
    comp_ds_info.redesign(c,1) = damage_state_attribute_mapping.redesign(ds_attr_filt);
    comp_ds_info.long_lead_time(c,1) = impedance_options.default_lead_time * damage_state_attribute_mapping.long_lead(ds_attr_filt);
    comp_ds_info.requires_shoring(c,1) = damage_state_attribute_mapping.requires_shoring(ds_attr_filt);
    comp_ds_info.resolved_by_scaffolding(c,1) = damage_state_attribute_mapping.resolved_by_scaffolding(ds_attr_filt);
    comp_ds_info.tmp_repair_class(c,1) = damage_state_attribute_mapping.tmp_repair_class(ds_attr_filt);
    comp_ds_info.tmp_repair_time_lower(c,1) = damage_state_attribute_mapping.tmp_repair_time_lower(ds_attr_filt);
    comp_ds_info.tmp_repair_time_upper(c,1) = damage_state_attribute_mapping.tmp_repair_time_upper(ds_attr_filt);
    if comp_ds_info.tmp_repair_class(c,1) > 0 % only grab values for components with temp repair times
        time_lower_quantity = damage_state_attribute_mapping.time_lower_quantity(ds_attr_filt);
        time_upper_quantity = damage_state_attribute_mapping.time_upper_quantity(ds_attr_filt);
        if iscell(time_lower_quantity)
            time_lower_quantity = str2double(time_lower_quantity);
        end
        if iscell(time_upper_quantity)
            time_upper_quantity = str2double(time_upper_quantity);
        end
        comp_ds_info.tmp_repair_time_lower_qnty(c,1) = time_lower_quantity;
        comp_ds_info.tmp_repair_time_upper_qnty(c,1) = time_upper_quantity;
    else
        comp_ds_info.tmp_repair_time_lower_qnty(c,1) = NaN;
        comp_ds_info.tmp_repair_time_upper_qnty(c,1) = NaN;
    end
    comp_ds_info.tmp_crew_size(c,1) = damage_state_attribute_mapping.tmp_crew_size(ds_attr_filt);

    % Find idx of this damage state in the subsystem attribute tables
    subsystem_filt = subsystems.id == comp_ds_info.subsystem_id(c,1);
    if comp_ds_info.subsystem_id(c,1) == 0
        % No subsytem
        comp_ds_info.n1_redundancy(c,1) = 0;
        comp_ds_info.parallel_operation(c,1) = 0;
        comp_ds_info.redundancy_threshold(c,1) = 0;
    elseif sum(subsystem_filt) ~= 1
        error('Could not find damage state attrubutes')
    else
        % Set Damage State Attributes
        comp_ds_info.n1_redundancy(c,1) = subsystems.n1_redundancy(subsystem_filt);
        comp_ds_info.parallel_operation(c,1) = subsystems.parallel_operation(subsystem_filt);
        comp_ds_info.redundancy_threshold(c,1) = subsystems.redundancy_threshold(subsystem_filt);
    end

end
damage.comp_ds_table = struct2table(comp_ds_info);

%% SAVE INPUTS AS MATLAB DATAFILE
save('simulated_inputs.mat',...
    'building_model','damage','damage_consequences','functionality',...
    'functionality_options','impedance_options','regional_impact',...
    'repair_time_options','tenant_units')

