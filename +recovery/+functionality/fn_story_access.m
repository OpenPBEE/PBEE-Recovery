function [ recovery_day, comp_breakdowns ] = fn_story_access(...
    damage, building_model, damage_consequences, system_operation_day, ...
    subsystems, functionality_options )
% Check each story for damage that would cause that story to be shut down due to
% issues of access
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage, loss, and repair time data for each 
%   component in the building
% building_model: struct
%   general attributes of the building model
% damage_consequences: struct
%   data structure containing simulated building consequences, such as red
%   tags and repair costs ratios
% system_operation_day: struct
%   simulation of recovery of operation for various systems in the building
% subsystems: table
%   data table containing information about each subsystem's attributes
% functionality_options: struct
%   recovery time optional inputs such as various damage thresholds
%
% Returns
% -------
% recovery_day: struct
%   simulation of the number of days each fault tree event is affecting access
%   in each story
% comp_breakdowns: struct
%   simulation of each components contributions to each of the fault tree events 

%% Initial Setup
num_reals = length(damage_consequences.red_tag);
num_units = length(damage.tenant_units);
num_stories = length(damage.tenant_units);
num_comps = height(damage.comp_ds_table);

% Pre-allocate data
recovery_day.stairs = zeros(num_reals,num_units);
recovery_day.stair_doors = zeros(num_reals,num_units);
recovery_day.fire_suppression = zeros(num_reals,num_units);
comp_breakdowns.stairs = zeros(num_reals,num_comps,num_units);
comp_breakdowns.fire_suppression = zeros(num_reals,num_comps,num_units);

%% Go through each story and check if there is sufficient story access (stairs and stairdoors)
if num_stories == 1 
    return % Re-occupancy of one story buildigns is not affected by stairway access
end

% Augment damage filters with door data
damage.fnc_filters.stairs = logical([damage.fnc_filters.stairs, 0]);
damage.fnc_filters.fire_drops = logical([damage.fnc_filters.fire_drops, 0]);
damage.fnc_filters.fire_building = logical([damage.fnc_filters.fire_building, 0]);
damage.fnc_filters.stair_doors = logical([zeros(1,num_comps), 1]);

% check if building has fire supprsion system
% must have both the building level (pipes) and tenant level (drops)components
fs_exists = any(damage.fnc_filters.fire_building) & any(damage.fnc_filters.fire_drops);

%% Stairs
% if stairs don't exist on a story, this will assume they are rugged (along with the stair doors)
for tu = 1:num_stories
    % Augment damage matrix with door data
    damage.tenant_units{tu}.num_comps = [damage.tenant_units{tu}.num_comps, building_model.stairs_per_story(tu)];
    racked_stair_doors = min(damage_consequences.racked_stair_doors_per_story(:,tu),building_model.stairs_per_story(tu));
    damage.tenant_units{tu}.qnt_damaged = [damage.tenant_units{tu}.qnt_damaged, racked_stair_doors];
    door_repair_day = (racked_stair_doors > 0) * functionality_options.door_racking_repair_day;
    damage.tenant_units{tu}.recovery.repair_complete_day = [damage.tenant_units{tu}.recovery.repair_complete_day, door_repair_day];

    % Quantify damaged stairs on this story
    repair_complete_day = damage.tenant_units{tu}.recovery.repair_complete_day;
    damaged_comps = damage.tenant_units{tu}.qnt_damaged;
    total_num_fs_drops = damage.tenant_units{tu}.num_comps .* damage.fnc_filters.fire_drops;

    % Replace story level repair day with building level for fire suppression system mains
    % This includes loss of utility, so its not just about component
    % damage, although its assigned to specific components. It would be
    % better to add utilities to the damage matrix
    if fs_exists % only do this if the building has a fire suppression system
        repair_complete_day(:,damage.fnc_filters.fire_building) = system_operation_day.building.fire;
        damaged_comps(:,damage.fnc_filters.fire_building) = system_operation_day.building.fire > 0;
        fire_access_day = zeros(num_reals,1); % day story becomes accessible from repair of fire suppression system
    end

    % Make sure zero repair days are NaN
    repair_complete_day(repair_complete_day == 0) = NaN;

    % Step through each unique component repair time and determine when
    % stairs stop affecting story access
    stair_access_day = zeros(num_reals,1); % day story becomes accessible from repair of stairs
    stairdoor_access_day = zeros(num_reals,1); % day story becomes accessible from repair of doors
    filt_all = damage.fnc_filters.stairs | damage.fnc_filters.fire_drops | damage.fnc_filters.stair_doors | damage.fnc_filters.fire_building;
    num_repair_time_increments = sum(filt_all); % possible unique number of loop increments
    for i = 1:num_repair_time_increments
        % number of functioning stairs
        num_dam_stairs = sum(damaged_comps .* damage.fnc_filters.stairs,2); % assumes comps are not simeltaneous
        num_racked_doors = sum(damaged_comps .* damage.fnc_filters.stair_doors,2); % assumes comps are not simeltaneous
        functioning_stairs = building_model.stairs_per_story(tu) - num_dam_stairs;
        functioning_stairdoors = building_model.stairs_per_story(tu) - num_racked_doors;

        % Fraction of functioning fire sprinkler drops
        if fs_exists % only do this if the building has a fire suppression system
            num_dam_fs_drops = sum(damaged_comps .* damage.fnc_filters.fire_drops,2); % assumes comps are not simeltaneous
            ratio_fs_drop_failed = max(num_dam_fs_drops ./ total_num_fs_drops,[],2); % Does not does not properly account for
                                                                                            % components in multuple PGs

            % Determine if the fire sprinkler system is operation at this story
            redundancy_threshold = max(damage.comp_ds_table.redundancy_threshold(damage.fnc_filters.fire_drops)); % should all be the same within a subsystem
            sufficient_fs_drop = ratio_fs_drop_failed <= redundancy_threshold;
            building_fs_operational = isnan(max(repair_complete_day(:,damage.fnc_filters.fire_building),[],2)); % has all damage been repaired 
            fs_operational = sufficient_fs_drop & building_fs_operational;
        end

        % Required egress with and without operational fire suppression system
        required_stairs_w_fs = max(functionality_options.min_egress_paths,functionality_options.egress_threshold .* building_model.stairs_per_story(tu)); 
        required_stairs_wo_fs = max(functionality_options.min_egress_paths,functionality_options.egress_threshold_wo_fs .* building_model.stairs_per_story(tu));

        % Determine Stair Access
        sufficient_stair_access_w_fs  = functioning_stairs >= required_stairs_w_fs;
        sufficient_stair_access_wo_fs  = functioning_stairs >= required_stairs_wo_fs;
        if fs_exists
            sufficient_stair_access = (sufficient_stair_access_w_fs .* fs_operational) | ...
                (sufficient_stair_access_wo_fs .* ~fs_operational);
        else
            % If there are is fire sprinkler system, use the more stringent egress requirements
            sufficient_stair_access = sufficient_stair_access_wo_fs;
        end

        % Determine Stair Door Acces
        sufficient_stairdoor_access_w_fs  = functioning_stairdoors >= required_stairs_w_fs;
        sufficient_stairdoor_access_wo_fs  = functioning_stairdoors >= required_stairs_wo_fs;
        if fs_exists
            sufficient_stairdoor_access = (sufficient_stairdoor_access_w_fs .* fs_operational) | ...
                (sufficient_stairdoor_access_wo_fs .* ~fs_operational);
        else
            % If there are is fire sprinkler system, use the more stringent egress requirements
            sufficient_stairdoor_access = sufficient_stairdoor_access_wo_fs;
        end

        % Add days in this increment to the tally
        delta_day = min(repair_complete_day(:,filt_all),[],2);
        delta_day(isnan(delta_day)) = 0;
        stair_access_day = stair_access_day + ~sufficient_stair_access .* delta_day;
        stairdoor_access_day = stairdoor_access_day + ~sufficient_stairdoor_access .* delta_day;

        if fs_exists
            % Determine when fs operation actually matters for egress
            fs_matters_for_stairs = sufficient_stair_access_w_fs & ~sufficient_stair_access;
            fs_matters_for_stairdoors = sufficient_stairdoor_access_w_fs & ~sufficient_stairdoor_access;
            fs_matters_for_access = fs_matters_for_stairs | fs_matters_for_stairdoors;
            
            % Determine when fs operation matters for safety (based on fire watch)
            if ~functionality_options.fire_watch
                % If no fire watch is in place, non-operation of the fire
                % sprinkler system will cause the space to not be
                % occupiable
                fs_matters_for_safety = ~fs_operational;
                fs_matters = fs_matters_for_safety | fs_matters_for_access;
            else
                % If a fire watch is in place, only accont for fs effect on
                % egress limitations
                fs_matters = fs_matters_for_access;
            end
            fire_access_day = fire_access_day + fs_matters .* delta_day;
        end

        % Add days to components that are affecting occupancy
        contributing_stairs = ((damaged_comps .* damage.fnc_filters.stairs) > 0)  .* ~sufficient_stair_access; % Count any damaged stairs for realization that have loss of story access
        contributing_stairs(:,end) = []; % remove added door column
        comp_breakdowns.stairs(:,:,tu) = comp_breakdowns.stairs(:,:,tu) + contributing_stairs .* delta_day;
        
        % Find fire sprinklers component that are contributing
        if fs_exists
             % Count when the fire sprinkler drops affects fs operation and matters for access
                                             % Its damaged  |  its a fire sprinkler drop   |  its affecting access | because damage is beyond the threshold for fire sprinkler drops
            contributing_fire_drop_comps = ((damaged_comps .* damage.fnc_filters.fire_drops ) > 0) .* fs_matters .* ~sufficient_fs_drop; 
            contributing_fire_drop_comps(:,end) = []; % remove added door column
            comp_breakdowns.fire_suppression(:,:,tu) = comp_breakdowns.fire_suppression(:,:,tu) + contributing_fire_drop_comps .* delta_day;
        end

        % Change the comps for the next increment
        repair_complete_day = repair_complete_day - delta_day;
        repair_complete_day(repair_complete_day <= 0) = NaN;
        fixed_comps_filt = isnan(repair_complete_day);
        damaged_comps(fixed_comps_filt) = 0;
    end

    % This story is not accessible if any story below has insufficient stair egress
    if tu == 1
        recovery_day.stairs(:,tu) = max(stair_access_day,max(recovery_day.stairs(:,1:tu),[],2));
    else
        % also the story below is not accessible if there is insufficient
        % stair egress at this story
        recovery_day.stairs(:,(tu-1):tu) = ones(1,2) .* max(stair_access_day,max(recovery_day.stairs(:,1:tu),[],2));
    end

    % Damage to doors only affects this story
    recovery_day.stair_doors(:,tu) = stairdoor_access_day;

    % Damage to fire sprinkler drops only affects this story (full building
    % fire sprinkler damage is adopted at every story earlier in this script)
    if fs_exists
        recovery_day.fire_suppression(:,tu) = fire_access_day;
    end
end

end % end function

