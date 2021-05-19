function [ damage ] = fn_restructure_repair_schedule( damage, system_schedule, ...
    repair_complete_day_per_system, systems, global_fail, replacement_time, surge_factor )
% Redistribute repair schedule data from the system and story level to the component level for use 
% in the functionality assessment (ie, put repair schedule data into the
% damage object)
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% system_schedule: Structure
%   repair time data for each system in isolation
% repair_complete_day_per_system: matrix [num reals x num systems]
%   Number of days from the start of each sequence to the completion of the
%   sequence considering the allocation of workers to each sequence (ie
%   some sequences start before others)
% systems: table
%   data table containing information about each system's attributes
% global_fail: logical array [num_reals x 1]
%   true if building has global failure which renders it un-repairable.
%   Typically for collapse or excessive resiudal cases.
% replacement_time: number
%   number of days required to replace the entire building
% surge_factor: number
%   amplification factor for temporary repair time based on a post disaster surge
%   in demand for skilled trades and construction supplies
%
% Returns
% -------
% damage: struct
%   contains per damage state damage and loss data for each component in
%   the building, including repair schedule data.
%
% Notes
% -----

%% Initialize Parameters
num_sys = height(systems);
num_stories = length(damage.story);

%% Redistribute repair schedule data
for sys = 1:num_sys
    % Calculate system repair times on each story
    system_duration = max(system_schedule.per_system{sys}.repair_complete_day,[],2); % total repair time spent in this system over all stories
    start_day = repair_complete_day_per_system(:,sys) - system_duration;
    story_start_day = start_day + system_schedule.per_system{sys}.repair_start_day;
    story_complete_day = start_day + system_schedule.per_system{sys}.repair_complete_day;

    % Re-distribute to each story
    sys_filt = damage.comp_ds_info.system == systems.id(sys); % identifies which ds idices are in this seqeunce  
    for s = 1:num_stories
        is_damaged = damage.story{s}.qnt_damaged(:,sys_filt) > 0;
        is_damaged = is_damaged*1;
        is_damaged(is_damaged == 0) = NaN;

        % Re-distribute repair days to component damage states
        damage.story{s}.recovery.repair_start_day(:,sys_filt) = is_damaged .* story_start_day(:,s);
        damage.story{s}.recovery.repair_complete_day(:,sys_filt) = is_damaged .* story_complete_day(:,s);
    end
end

% Post process for global failure and temp repairs
for s = 1:num_stories
    % Replace global failure cases with full repair time
    damage.story{s}.recovery.repair_start_day(global_fail,:) = 0;
    damage.story{s}.recovery.repair_complete_day(global_fail,:) = replacement_time;

    % Calculate the day repairs are completed considering temporary repairs
    repair_complete_day_no_NaN = max(damage.story{s}.recovery.repair_complete_day,0);
    tmp_repair_time = surge_factor * damage.comp_ds_info.tmp_fix_time_no_zeros;
    damage.story{s}.recovery.repair_complete_day_w_tmp = min(repair_complete_day_no_NaN, tmp_repair_time);

    % Calculate the day repairs start considering temporary repairs
    damage.story{s}.recovery.start_day_w_tmp = damage.story{s}.recovery.repair_start_day;
    damage.story{s}.recovery.tmp_day_controls = damage.story{s}.recovery.repair_complete_day_w_tmp < repair_complete_day_no_NaN;
    damage.story{s}.recovery.repair_start_day_w_tmp(damage.story{s}.recovery.tmp_day_controls) = 0;

    % Change zeros in complete day back to NaN (ie no damage)
    damage.story{s}.recovery.repair_complete_day_w_tmp(damage.story{s}.recovery.repair_complete_day_w_tmp == 0) = NaN;
end


end

