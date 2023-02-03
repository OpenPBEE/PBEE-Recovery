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
model_name = '001'; % Name of the model;
                     % inputs are expected to be in a directory with this name
                     % outputs will save to a directory with this name
model_dir = ['inputs' filesep 'example_pelicun_inputs' filesep model_name]; % Directory where the simulated inputs are located

%% Load Pelicun Outputs
pelicun_dir = [model_dir filesep 'pelicun_data'];

% Pull basic model info from Pelicun Inputs
fileID = fopen([pelicun_dir filesep 'input.json'],'r');
pelicun_inputs = jsondecode(fscanf(fileID,'%s'));
fclose(fileID);
num_stories = str2double(pelicun_inputs.DL.Asset.NumberOfStories);
total_cost = str2double(pelicun_inputs.DL.Losses.BldgRepair.ReplacementCost.Median);
plan_area = str2double(pelicun_inputs.DL.Asset.PlanArea);

% Pull components from DL_model.json
comps = readtable([pelicun_dir filesep 'CMP_QNT.csv']);

% Pull repair cost realizations
DV_rec_cost_agg = readtable([pelicun_dir filesep 'DL_summary.csv']);

% Pull realizations of damaged components
DMG = readtable([pelicun_dir filesep 'DMG_sample.csv']);
frag_col_filt = ~cellfun(@isempty,regexp(DMG.Properties.VariableNames,'^B_')) | ...
                ~cellfun(@isempty,regexp(DMG.Properties.VariableNames,'^C_')) | ...
                ~cellfun(@isempty,regexp(DMG.Properties.VariableNames,'^D_')) | ...
                ~cellfun(@isempty,regexp(DMG.Properties.VariableNames,'^E_')) | ...
                ~cellfun(@isempty,regexp(DMG.Properties.VariableNames,'^F_'));
DMG = DMG(:,frag_col_filt); % Filt to only component level damage
DMG_ids = DMG.Properties.VariableNames;

% Pull realization of repair time per componentDS
DV = readtable([pelicun_dir filesep 'DV_bldg_repair_sample.csv']);
rec_time_filt = ~cellfun(@isempty,regexp(DV.Properties.VariableNames,'^TIME'));
DV_time = DV(:,rec_time_filt); % Filt to only component level damage
repair_cost_filt = ~cellfun(@isempty,regexp(DV.Properties.VariableNames,'^COST'));
DV_cost = DV(:,repair_cost_filt); % Filt to only component level damage

%% Load ATC 138 model input data
tenant_unit_list = readtable([model_dir filesep 'tenant_unit_list.csv']);
ds_attributes = readtable(['static_tables' filesep 'damage_state_attribute_mapping.csv']);

% general model inputs
fileID = fopen([model_dir filesep 'general_inputs.json'],'r');
general_inputs = jsondecode(fscanf(fileID,'%s'));
fclose(fileID);

%% Develop building_model.json
% Count the number of stairs in the building
stair_filt = contains(comps.ID,'C.20.11'); 
if any(stair_filt)
    num_stairs = min(comps.Theta_0(stair_filt)); % Assumes number of vertical egress routes is the min number of stairs on any story. This is faulty logic and wont hold true for all comp tables 
else
    num_stairs = 0;
end
% Count the number of elevator bays in the building
elev_filt = contains(comps.ID,'D.10.14'); 
if any(elev_filt)
    num_elev_bays = max(max(comps.Theta_0(elev_filt)),0);  % Assumes the number of elevator bays is the max on any story
else
    num_elev_bays = 0;
end

% Set Variables
building_model.building_value = total_cost; % num
building_model.num_stories = num_stories; % int
building_model.area_per_story_sf = plan_area*ones(num_stories,1); % num_stories x 1 array
building_model.ht_per_story_ft = general_inputs.typ_story_ht_ft*ones(num_stories,1); % num_stories x 1 array
building_model.edge_lengths = [general_inputs.length_side_1_ft; general_inputs.length_side_2_ft].*ones(1, num_stories); % 2 x num_stories array (json flips the others)
building_model.struct_bay_area_per_story = general_inputs.typ_struct_bay_area_ft*ones(num_stories,1); % num_stories x 1 array
building_model.num_entry_doors = general_inputs.num_entry_doors; % int
building_model.num_elevators = num_elev_bays; % int
building_model.stairs_per_story = num_stairs*ones(num_stories,1); % num_stories x 1 array
building_model.occupants_per_story = general_inputs.peak_occ_rate*building_model.area_per_story_sf; % num_stories x 1 array

% Write file
fileID = fopen([model_dir filesep 'building_model.json'],'w');
fprintf(fileID,'%s',jsonencode(building_model));
fclose(fileID);

%% Develop damage_consequences.json
% Pull data from Pelicun structure 
sim_repair_cost = DV_rec_cost_agg.repair_cost_;
sim_replacement = DV_rec_cost_agg.collapse | DV_rec_cost_agg.irreparable;

% Set Variables
damage_consequences.repair_cost_ratio_total = sim_repair_cost / building_model.building_value;  % array, num real x 1
damage_consequences.simulated_replacement = sim_replacement;

% HARD CODED VARIABLES -- assumed no racked doors
damage_consequences.racked_stair_doors_per_story = zeros(length(sim_repair_cost),building_model.num_stories); % array, num real x num stories
damage_consequences.racked_entry_doors_side_1  = zeros(size(sim_repair_cost)); % array, num real x 1
damage_consequences.racked_entry_doors_side_2  = zeros(size(sim_repair_cost)); % array, num real x 1

% Write file
fileID = fopen([model_dir filesep 'damage_consequences.json'],'w');
fprintf(fileID,'%s',jsonencode(damage_consequences));
fclose(fileID);

%% Build comp_population.csv
comp_population.story = zeros(num_stories*3,1);
comp_population.dir = zeros(num_stories*3,1);
for c = 1:height(comps)
    idx = 1;
    comp = comps(c,:);            
    frag_id = comp.ID{1};
    frag_id([2,5]) = []; % Remove extra periods
    frag_id = strrep(frag_id,'.','_');
    comp_population.(frag_id) = zeros(num_stories*3,1);
    loc = comp.Location{1};
    dir = comp.Direction{1};
    for s = 1:num_stories
        if  strcmp(loc,'all')
            is_story = true;
        elseif  strcmp(loc,'roof')
            is_story = s == num_stories;
        elseif  contains(loc,'--')
            is_story = s >= str2double(loc(1)) & s<= str2double(loc(end));
        else
            loc_vec = str2double(strsplit(loc));
            is_story = ismember(s,loc_vec);
        end
        
        for d = 1:3
            comp_population.story(idx) = s;
            comp_population.dir(idx) = d;
            dir_str = strrep(dir,'0','3'); % replace nondirection identifier
            dir_vec = str2double(strsplit(dir_str,','));
            is_dir = ismember(d,dir_vec);

            if is_story && is_dir
                % Assign to component population table (add duplicates)
                comp_population.(frag_id)(idx) = comp_population.(frag_id)(idx) + comp.Theta_0;
            end

            idx = idx + 1;
        end
    end
end

% Convert to table and save
comp_population = struct2table(comp_population);
writetable(comp_population, [model_dir filesep 'comp_population.csv']);

%% Build comp_ds_list.csv
idx = 0;
unique_comps = unique(comps.ID); % Only one entry per unique component id
for c = 1:length(unique_comps)
    frag_id = unique_comps{c};
    frag_id([2,5]) = []; % Remove extra periods
    ds_filt = ~cellfun(@isempty,regexp(frag_id,ds_attributes.fragility_id_regex));
    ds_match = ds_attributes(ds_filt,:);
    for ds = 1:height(ds_match)
        idx = idx + 1;
        comp_ds_list.comp_id{idx,1} = frag_id;
        comp_ds_list.ds_seq_id(idx,1) = ds_match.ds_index(ds);
        if strcmp(ds_match.sub_ds_index{ds},'NA')
            comp_ds_list.ds_sub_id(idx,1) = 1;
        else
            comp_ds_list.ds_sub_id(idx,1) = str2double(ds_match.sub_ds_index{ds});
        end
    end
end

% Convert to table and save
comp_ds_list = struct2table(comp_ds_list);
writetable(comp_ds_list, [model_dir filesep 'comp_ds_list.csv']);

%% Develop simulated damage.json
[num_reals,~] = size(DMG(:,2:end));

% Make some rough assumptions to distribute damage to 4 sides (for external
% falling hazards)
ratio_damage_per_side = rand(num_reals,4); % assumes square footprint
ratio_damage_per_side = ratio_damage_per_side ./ sum(ratio_damage_per_side,2); % force it to add to one

% Set Variables
count = 0;
for s = 1:num_stories
    % Initialize variables
    simulated_damage.story(s).qnt_damaged = zeros(num_reals,height(comp_ds_list));
    simulated_damage.story(s).worker_days = zeros(num_reals,height(comp_ds_list));
    simulated_damage.story(s).repair_cost = zeros(num_reals,height(comp_ds_list));
    simulated_damage.story(s).qnt_damaged_side_1 = zeros(num_reals,height(comp_ds_list));
    simulated_damage.story(s).qnt_damaged_side_2 = zeros(num_reals,height(comp_ds_list));
    simulated_damage.story(s).qnt_damaged_side_3 = zeros(num_reals,height(comp_ds_list));
    simulated_damage.story(s).qnt_damaged_side_4 = zeros(num_reals,height(comp_ds_list));
    simulated_damage.story(s).qnt_damaged_dir_1 = zeros(num_reals,height(comp_ds_list));
    simulated_damage.story(s).qnt_damaged_dir_2 = zeros(num_reals,height(comp_ds_list));
    simulated_damage.story(s).qnt_damaged_dir_3 = zeros(num_reals,height(comp_ds_list));
    simulated_damage.story(s).num_comps = zeros(height(comp_ds_list),1);
       
    % Go through each ds in PELICUN outputs and assign to simualated damage
    % data structure
    for c = 1:length(DMG_ids)
        % Identify attributes of column IDS
        DMG_id = strsplit(DMG_ids{c},'_');
        frag_id = [DMG_id{1} DMG_id{2} DMG_id{3} '.' DMG_id{4}];
        frag_filt = strcmp(comp_ds_list.comp_id,frag_id);
        loc_id = str2double(DMG_id{end-2});
        dir_id = str2double(DMG_id{end-1});
        if dir_id == 0
            dir_id = 3; % Change nondirection indexing
        end
        ds_id = str2double(DMG_id{end});
        
        % Find the associated column in the repair time table
        frag_id_DV = [DMG_id{1} '_' DMG_id{2} '_' DMG_id{3} '_' DMG_id{4} '_' num2str(ds_id) '_' DMG_id{5} '_' DMG_id{6}];
        DV_filt = contains(DV_time.Properties.VariableNames,frag_id_DV);
        
        % Assign simulated damage to new structure
        if loc_id == s  && ds_id > 0 && any(frag_filt) % Only if there are components on this story
            comp_ds = comp_ds_list(frag_filt,:);
            seq_ds_filt = comp_ds_list.ds_seq_id == comp_ds.ds_seq_id(ds_id);
            sub_ds_filt = comp_ds_list.ds_sub_id == comp_ds.ds_sub_id(ds_id);
            sim_dmg_idx_filt = (frag_filt & seq_ds_filt & sub_ds_filt)';
            if sum(sim_dmg_idx_filt) == 1 && sum(DV_filt) == 1 % if you find matching components
                % Assign Damage data
                dmg_data = DMG{:,c};
                dmg_data(isnan(dmg_data)) = 0; % Change blank cases to no damage
                simulated_damage.story(s).qnt_damaged(:,sim_dmg_idx_filt) = ...
                    simulated_damage.story(s).qnt_damaged(:,sim_dmg_idx_filt) + dmg_data; % add number of damaged component amongst directions and multiple comps of the same frag id
                
                % Assign Repair time data
                repair_time_data = DV_time{:,DV_filt};
                repair_time_data(isnan(repair_time_data)) = 0; % Change blank cases to no damage
                simulated_damage.story(s).worker_days(:,sim_dmg_idx_filt) = ...
                    simulated_damage.story(s).worker_days(:,sim_dmg_idx_filt) + repair_time_data; % add the repair time amongst directions and multiple comps of the same frag id
                
                % Assign Repair Cost data
                repair_cost_data = DV_cost{:,DV_filt};
                repair_cost_data(isnan(repair_cost_data)) = 0; % Change blank cases to no damage
                simulated_damage.story(s).repair_cost(:,sim_dmg_idx_filt) = ...
                    simulated_damage.story(s).repair_cost(:,sim_dmg_idx_filt) + repair_cost_data; % add the repair time amongst directions and multiple comps of the same frag id
                
                % Assign Damage Data Per Direction
                for dir = 1:3
                    if dir_id == dir % only for the direction associated with this DMG column
                        simulated_damage.story(s).(['qnt_damaged_dir_' num2str(dir)])(:,sim_dmg_idx_filt) = ...
                        simulated_damage.story(s).(['qnt_damaged_dir_' num2str(dir)])(:,sim_dmg_idx_filt) + dmg_data; % add number of damaged component amongst directions and multiple comps of the same frag id
                    end
                end
            else
                error('Location in new damage state structure could not be found for this compoennt DS')
            end
        end
    end
    
    % Randomly split damage between 4 sides, this will only matter
    % for cladding components
    simulated_damage.story(s).qnt_damaged_side_1 = ...
        ratio_damage_per_side(:,1).*simulated_damage.story(s).qnt_damaged;
    simulated_damage.story(s).qnt_damaged_side_2 = ...
        ratio_damage_per_side(:,2).*simulated_damage.story(s).qnt_damaged;
    simulated_damage.story(s).qnt_damaged_side_3 = ...
        ratio_damage_per_side(:,3).*simulated_damage.story(s).qnt_damaged;
    simulated_damage.story(s).qnt_damaged_side_4 = ...
        ratio_damage_per_side(:,4).*simulated_damage.story(s).qnt_damaged;
    
    % Assign component quantities
    for c = 1:height(comps)
        comp = comps(c,:);
        loc = comp.Location{1};
        if  strcmp(loc,'all')
            is_story = true;
        elseif  strcmp(loc,'roof')
            is_story = s == num_stories;
        elseif  contains(loc,'--')
            is_story = s >= str2double(loc(1)) & s<= str2double(loc(end));
        else
            loc_vec = str2double(strsplit(loc));
            is_story = ismember(s,loc_vec);
        end
        
        if is_story
            frag_id = comp.ID{1};
            frag_id([2,5]) = []; % Remove extra periods
            frag_filt = strcmp(comp_ds_list.comp_id,frag_id)';
            simulated_damage.story(s).num_comps(frag_filt) = ...
                simulated_damage.story(s).num_comps(frag_filt) + comp.Theta_0;
        end
    end
end
            
% Write file
fileID = fopen([model_dir filesep 'simulated_damage.json'],'w');
fprintf(fileID,'%s',jsonencode(simulated_damage));
fclose(fileID);

