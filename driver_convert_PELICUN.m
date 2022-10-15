%% Script Converts PELICUN outputs into PBEE-Recovery tool inputs

% Required inputs
%    - comp_ds_list.csv
%    - tenant_unit_list.csv
%    - input_parameters.json
%    - DL_model.json
%    - IF_delays.csv
%    - DV_rec_cost_agg.csv
%    - DV_rec_time.csv
%    - DMG.csv

% Assumptions: (specific to 16 story treads model)
%    - assume rugged entry doors
%    - Stairs run the whole length of the building
%    - Residential occupancy
%    - uniform 10ft story ht
%    - 33ft x 33ft structural bay area
%    - square building (100ft sides)
%    - 16 stories (4 basement, 12 above grade)
%    - Stability IF longer than 10 days = red tag


clear all
close all
clc
rehash

%% Define Inputs
model_name = '16-story_RCSW_475yr_Example'; % Name of the model;
                     % inputs are expected to be in a directory with this name
                     % outputs will save to a directory with this name
model_dir = ['inputs' filesep model_name]; % Directory where the simulated inputs are located

% Set additional Assumptions not provided by TREADS or PELICUN
ht_per_story_ft = 10*ones(16,1);
edge_lengths = 100*ones(16,2);
struct_bay_area_per_story = 33*33*ones(16,1);
peak_occ_rate = 3.1/1000; % residential peak occupancy rates (occupants per sqft) per FEMA P-58 table 3-1
num_basement_levels = 4;
num_ag_levels = 12;
num_entry_doors = 2; % int, number of entry/exit doors for the building
total_cost = 47564000;
elevator_quantity = 2;
floor_area = 10000*ones(16,1);

%% Load ATC 138 model input data
comp_ds_list = readtable([model_dir filesep 'comp_ds_list.csv']);
tenant_unit_list = readtable([model_dir filesep 'tenant_unit_list.csv']);

%% Load Pelicun Outputs
pelicun_dir = [model_dir filesep 'pelicun_data'];

% Pull components from DL_model.json
fileID = fopen([pelicun_dir filesep 'DL_model.json'],'r');
DL_model = jsondecode(fscanf(fileID,'%s'));
fclose(fileID);
comps = DL_model.DamageAndLoss.Components;

% Pull repair cost realizations
DV_rec_cost_agg = readtable([pelicun_dir filesep 'DV_rec_cost_agg.csv']);
sim_repair_cost = sum(str2double(DV_rec_cost_agg{2:end,2:end}),2);

% Pull realizations of damaged components
DMG = readtable([pelicun_dir filesep 'DMG.csv']);
DMG_FG = DMG{1,2:end};
DMG_PG = DMG{2,2:end};
DMG_DS = DMG{3,2:end};
DMG_data = str2double(DMG{5:end,2:end});

% Pull realization of repair time
DV_rec_time = readtable([pelicun_dir filesep 'DV_rec_time.csv']);
DV_rec_time_data = str2double(DV_rec_time{5:end,2:end});



%% Develop building_model.json from treads inputs
comp_ids = fieldnames(comps);
stair_filt = contains(comp_ids,'C2011'); % find all stair fragilities
stair_ids = comp_ids(stair_filt);
stairs_per_story = 0;
for c = 1:length(stair_ids)
    qty = str2double(strsplit(comps.(stair_ids{c}).median_quantity,','));
    % comps.(frag_id).location  % Number of elements doesnt line up
    % with location field, therefor I am not using
    stairs_per_story = stairs_per_story + qty(1); % just take the first field (assumes they are all the same)
end

% Set Variables
building_model.building_value = total_cost; % num
building_model.num_stories = length(floor_area); % int
building_model.total_area_sf = sum(floor_area); % number
building_model.area_per_story_sf = floor_area; % num_stories x 1 array
building_model.ht_per_story_ft = ht_per_story_ft; % num_stories x 1 array
building_model.edge_lengths = edge_lengths; % num_stories x 2 array
building_model.struct_bay_area_per_story = struct_bay_area_per_story; % num_stories x 1 array
building_model.num_entry_doors = num_entry_doors; % int
building_model.num_elevators = elevator_quantity; % int
building_model.stairs_per_story = stairs_per_story*ones(building_model.num_stories,1); % num_stories x 1 array
building_model.occupants_per_story = peak_occ_rate*building_model.area_per_story_sf; % num_stories x 1 array

% Write file
fileID = fopen([model_dir filesep 'building_model.json'],'w');
fprintf(fileID,'%s',jsonencode(building_model));
fclose(fileID);

%% Develop damage_consequences.json
% Set Variables

damage_consequences.racked_stair_doors_per_story = zeros(length(damage_consequences.red_tag),building_model.num_stories); % array, num real x num stories
damage_consequences.racked_entry_doors_side_1  = zeros(size(damage_consequences.red_tag)); % array, num real x 1
damage_consequences.racked_entry_doors_side_2  = zeros(size(damage_consequences.red_tag)); % array, num real x 1
damage_consequences.repair_cost_ratio = sim_repair_cost / building_model.building_value;  % array, num real x 1

% note: calculate these directly by incorporating red tag assessment into
% PBEE recovery
damage_consequences.red_tag = 0; % array, num real x 1
damage_consequences.inpsection_trigger = 0;  % array, num real x 1


% Write file
fileID = fopen([model_dir filesep 'damage_consequences.json'],'w');
fprintf(fileID,'%s',jsonencode(damage_consequences));
fclose(fileID);

%% Develop simulated damage.json
[num_reals,num_DMG] = size(DMG_data);

story_str_converter = strsplit(sprintf('%03d ',[flip(1:num_basement_levels) + 100, 1:num_ag_levels]));
story_str_converter(end) = [];

ratio_damage_per_side = rand(num_reals,4); % assumes square footprint
ratio_damage_per_side = ratio_damage_per_side ./ sum(ratio_damage_per_side,2); % force it to add to one

% Set Variables
count = 0;
for s = 1:length(story_str_converter)
    % Initialize variables
    simulated_damage(s).qnt_damaged = zeros(num_reals,height(comp_ds_list));
    simulated_damage(s).worker_days = zeros(num_reals,height(comp_ds_list));
    simulated_damage(s).qnt_damaged_side_1 = zeros(num_reals,height(comp_ds_list));
    simulated_damage(s).qnt_damaged_side_2 = zeros(num_reals,height(comp_ds_list));
    simulated_damage(s).qnt_damaged_side_3 = zeros(num_reals,height(comp_ds_list));
    simulated_damage(s).qnt_damaged_side_4 = zeros(num_reals,height(comp_ds_list));
    simulated_damage(s).num_comps = zeros(height(comp_ds_list),1);
        
    % Go through each ds in PELICUN outputs
    exp = ['\d*', story_str_converter{s}, '\d$'];
    story_filt = ~cellfun(@isempty,regexp(DMG_PG,exp));
    for c = 1:height(comp_ds_list)
        FG_filt = strcmp(DMG_FG,comp_ds_list.comp_id{c});
        exp = sprintf ('^%i',comp_ds_list.ds_seq_id(c));
        seq_ds_filt = ~cellfun(@isempty,regexp(DMG_DS,exp));
        exp = sprintf ('%i$',comp_ds_list.ds_sub_id(c));
        sub_ds_filt = ~cellfun(@isempty,regexp(DMG_DS,exp));
        DMG_filt = FG_filt & seq_ds_filt & sub_ds_filt & story_filt;
        if sum(DMG_filt) == 1
            count = count + 1;
            simulated_damage(s).qnt_damaged(:,c) = DMG_data(:,DMG_filt);
            simulated_damage(s).worker_days(:,c) = DV_rec_time_data(:,DMG_filt);
            
            frag_id = strrep(DMG_FG{DMG_filt},'.','_');
            qty = str2double(strsplit(comps.(frag_id).median_quantity,','));
            % comps.(frag_id).location  % Number of elements doesnt line up
            % with location field, therefor I am not using
            if length(qty) > 1
                test = 5;
            end
            simulated_damage(s).num_comps(c) = sum(qty); % total number per level is the sum of the array
            
        elseif sum(DMG_filt) > 1
            error('couldnt find comp ds')
        end 
    end
    
    % Randomly split damage between 4 sides, this will only matter
    % for cladding components
    simulated_damage(s).qnt_damaged_side_1 = ratio_damage_per_side(:,1).*simulated_damage(s).qnt_damaged;
    simulated_damage(s).qnt_damaged_side_2 = ratio_damage_per_side(:,2).*simulated_damage(s).qnt_damaged;
    simulated_damage(s).qnt_damaged_side_3 = ratio_damage_per_side(:,3).*simulated_damage(s).qnt_damaged;
    simulated_damage(s).qnt_damaged_side_4 = ratio_damage_per_side(:,4).*simulated_damage(s).qnt_damaged;
end

% if count ~= num_DMG
%     error('did not use all columns')
% end

% Write file
fileID = fopen([model_dir filesep 'simulated_damage.json'],'w');
fprintf(fileID,'%s',jsonencode(simulated_damage));
fclose(fileID);

