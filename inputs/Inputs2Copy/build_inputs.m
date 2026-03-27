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

%% PULL STATIC DATA
% Load required data tables
component_attributes = readtable([static_data_dir filesep 'component_attributes.csv']);
damage_state_attribute_mapping = readtable([static_data_dir filesep 'damage_state_attribute_mapping.csv']);
subsystems = readtable([static_data_dir filesep 'subsystems.csv']);
tenant_function_requirements = readtable([static_data_dir filesep 'tenant_function_requirements.csv']);

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
% if building_model.num_stories == 1
building_model.edge_lengths = building_model.edge_lengths';
% end

% List of tenant units within the building and their basic attributes
tenant_unit_list = readtable('tenant_unit_list.csv');

% List of component and damage states ids associated with the damage matrix
comp_ds_list = readtable('comp_ds_list.csv');

% List of component and damage states in the performance model
comp_population = readtable('comp_population.csv');

% Read header row unaltered by matlab
fid = fopen('comp_population.csv');
comp_header = strsplit(fgetl(fid), ',');
fclose(fid);
comp_list = strrep(comp_header(3:end),'_','.');
building_model.comps.comp_list = comp_list;

% Go through each story and assign component populations
drs = unique(comp_population.dir);
for s = 1:building_model.num_stories
    for d = 1:length(drs)
        filt = comp_population.story == s & comp_population.dir == drs(d);
        building_model.comps.story{s}.(['qty_dir_' num2str(drs(d))]) = comp_population{filt,3:end};
    end
end

 % Set comp info table
for c = 1:length(comp_list)
    % Find the component attributes of this component
    comp_attr_filt = strcmp(string(component_attributes.fragility_id),comp_list{c});
    if sum(comp_attr_filt) ~= 1
        error('Could not find component attrubutes')
    else
        comp_attr = component_attributes(comp_attr_filt,:);
    end
    
    comp_info.comp_id{c,1} = comp_list{c};
    comp_info.comp_idx(c,1) = c;
    comp_info.structural_system(c,1)  = comp_attr.structural_system;
    comp_info.structural_system_alt(c,1)  = comp_attr.structural_system_alt;
    comp_info.structural_series_id(c,1)  = comp_attr.structural_series_id;
end
building_model.comps.comp_table = struct2table(comp_info);

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
    num_reals = length(damage_consequences.repair_cost_ratio_total);
    functionality.utilities.electrical = zeros(num_reals,1);
    functionality.utilities.water = zeros(num_reals,1);
    functionality.utilities.gas = zeros(num_reals,1);
end

% Simulated component damage per tenant unit for each realization of the
% monte carlo simulation
sim_damage = jsondecode(fileread('simulated_damage.json'));

% Transform damage per story array to cell array to work with later code
if isfield(sim_damage,'story')
    for s = 1:length(sim_damage.story)
        damage.story{s} = sim_damage.story(s);
        if isfield(damage.story{s},'num_comps')
            damage.story{s}.num_comps = damage.story{s}.num_comps'; 
        end
    end
end

% Transform damage per tenant unit array to cell array to work with later code
if isfield(sim_damage,'tenant_units')
    for tu = 1:length(sim_damage.tenant_units)
        damage.tenant_units{tu} = sim_damage.tenant_units(tu);
        if isfield(damage.tenant_units{tu},'num_comps')
            damage.tenant_units{tu}.num_comps = damage.tenant_units{tu}.num_comps'; 
        end
    end
end


%% LOAD DEFAULT OPTIONAL INPUTS
% various assessment otpions. Set to default options in the
% optional_inputs.m file. This file is expected to be in this input
% directory. This file can be customized for each assessment if desired.
optional_inputs

%% PULL ADDITIONAL ATTRIBUTES FROM THE STATIC DATA TABLES
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
tenant_units.is_data_required = zeros(height(tenant_units),1);

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
    tenant_units.is_data_required(tu) = tenant_function_requirements.is_data_required(fnc_requirements_filt);
end


% Pull default component and damage state attributes for each component 
% in the comp_ds_list
for c = 1:height(comp_ds_list)
    
    % Find the component attributes of this component
    comp_attr_filt = strcmp(string(component_attributes.fragility_id),comp_ds_list.comp_id{c});
    if sum(comp_attr_filt) ~= 1
        error('Could not find component attrubutes')
    else
        comp_attr = component_attributes(comp_attr_filt,:);
    end
    
    % Find the damage state attributes of this componnt
    ds_comp_filt = ~cellfun(@isempty,regexp(comp_ds_list.comp_id{c},damage_state_attribute_mapping.fragility_id_regex));
    ds_seq_filt = damage_state_attribute_mapping.ds_index == comp_ds_list.ds_seq_id(c);
    if comp_ds_list.ds_sub_id(c) == 1
        ds_sub_filt = ismember(damage_state_attribute_mapping.sub_ds_index,{'1','NA'});
    else
        ds_sub_filt = strcmp(damage_state_attribute_mapping.sub_ds_index,num2str(comp_ds_list.ds_sub_id(c)));
    end
    ds_filt = ds_comp_filt & ds_seq_filt & ds_sub_filt;
    
    if sum(ds_filt) ~= 1
        error('Could not find damage state attrubutes')
    else
        ds_attr = damage_state_attribute_mapping(ds_filt,:);
    end
    
    %% Populate data for each damage state
    % Basic Component and DS identifiers
    comp_ds_info.comp_id{c,1} = comp_ds_list.comp_id{c};
    comp_ds_info.comp_type_id{c,1} = comp_ds_list.comp_id{c}(1:5); % first 5 characters indicate the type
    comp_ds_info.comp_idx(c,1) = c;
    comp_ds_info.ds_seq_id(c,1) = ds_attr.ds_index;
    comp_ds_info.ds_sub_id(c,1) = str2double(strrep(ds_attr.sub_ds_index{1},'NA','1'));

    % Set Component Attributes
    comp_ds_info.system(c,1) = comp_attr.system_id;
    comp_ds_info.subsystem_id(c,1) = comp_attr.subsystem_id;
    comp_ds_info.structural_system(c,1)  = comp_attr.structural_system;
    comp_ds_info.structural_system_alt(c,1)  = comp_attr.structural_system_alt;
    comp_ds_info.structural_series_id(c,1)  = comp_attr.structural_series_id;
    comp_ds_info.unit{c,1} = comp_attr.unit{1};
    comp_ds_info.unit_qty(c,1) = comp_attr.unit_qty;
    comp_ds_info.service_location{c,1} = comp_attr.service_location{1};

    % Set Damage State Attributes
    comp_ds_info.is_sim_ds(c,1) = ds_attr.is_sim_ds;
    comp_ds_info.safety_class(c,1) = ds_attr.safety_class;
    comp_ds_info.affects_envelope_safety(c,1) = ds_attr.affects_envelope_safety;
    comp_ds_info.ext_falling_hazard(c,1) = ds_attr.exterior_falling_hazard;
    comp_ds_info.int_falling_hazard(c,1) = ds_attr.interior_falling_hazard;
    comp_ds_info.global_hazardous_material(c,1) = ds_attr.global_hazardous_material;
    comp_ds_info.local_hazardous_material(c,1) = ds_attr.local_hazardous_material;
    comp_ds_info.weakens_fire_break(c,1) = ds_attr.weakens_fire_break;
    comp_ds_info.affects_access(c,1) = ds_attr.affects_access;
    comp_ds_info.damages_envelope_seal(c,1) = ds_attr.damages_envelope_seal;
    comp_ds_info.affects_roof_function(c,1) = ds_attr.affects_roof_function;
    comp_ds_info.obstructs_interior_space(c,1) = ds_attr.obstructs_interior_space;
    comp_ds_info.impairs_system_operation(c,1) = ds_attr.impairs_system_operation;
    comp_ds_info.causes_flooding(c,1) = ds_attr.causes_flooding;
    comp_ds_info.interior_area_factor(c,1) = ds_attr.interior_area_factor;
    comp_ds_info.interior_area_conversion_type(c,1) = ds_attr.interior_area_conversion_type;
    comp_ds_info.exterior_surface_area_factor(c,1) = ds_attr.exterior_surface_area_factor;
    comp_ds_info.exterior_falling_length_factor(c,1) = ds_attr.exterior_falling_length_factor;
    comp_ds_info.crew_size(c,1) = ds_attr.crew_size;
    comp_ds_info.permit_type(c,1) = ds_attr.permit_type;
    comp_ds_info.redesign(c,1) = ds_attr.redesign;
    comp_ds_info.long_lead_time(c,1) = impedance_options.default_lead_time * ds_attr.long_lead;
    comp_ds_info.requires_shoring(c,1) = ds_attr.requires_shoring;
    comp_ds_info.resolved_by_scaffolding(c,1) = ds_attr.resolved_by_scaffolding;
    comp_ds_info.tmp_repair_class(c,1) = ds_attr.tmp_repair_class;
    comp_ds_info.tmp_repair_time_lower(c,1) = ds_attr.tmp_repair_time_lower;
    comp_ds_info.tmp_repair_time_upper(c,1) = ds_attr.tmp_repair_time_upper;
    if comp_ds_info.tmp_repair_class(c,1) > 0 % only grab values for components with temp repair times
        time_lower_quantity = ds_attr.time_lower_quantity;
        time_upper_quantity = ds_attr.time_upper_quantity;
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
    comp_ds_info.tmp_crew_size(c,1) = ds_attr.tmp_crew_size;

    % Subsystem attributes
    subsystem_filt = subsystems.id == comp_attr.subsystem_id;
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

%% Check missing data
% Engineering Repair Cost Ratio - Assume is the sum of all component repair
% costs that require redesign
if ~isfield(damage_consequences,'repair_cost_ratio_engineering')
    eng_filt = logical(damage.comp_ds_table.redesign');
    damage_consequences.repair_cost_ratio_engineering = zeros(size(damage_consequences.repair_cost_ratio_total));
    for s = 1:length(sim_damage.story)
        damage_consequences.repair_cost_ratio_engineering = ...
            damage_consequences.repair_cost_ratio_engineering + ...
            sum(sim_damage.story(s).repair_cost(:,eng_filt),2);
    end
end

%% SAVE INPUTS AS MATLAB DATAFILE
save('simulated_inputs.mat',...
    'building_model','damage','damage_consequences','functionality',...
    'functionality_options','impedance_options',...
    'repair_time_options','tenant_units')

