function [ damage ] = fn_restructure_repair_schedule( damage, system_schedule, ...
    repair_complete_day_per_system, systems, tmp_repair_complete_day)
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
% tmp_repair_complete_day: array [num_reals x num_comp]
%   contains the day (after the earthquake) the temporary repair time is 
%   resolved per damage state damage and realization
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
num_units = length(damage.tenant_units);

%% Redistribute repair schedule data
for sys = 1:num_sys
    % Calculate system repair times on each story
    system_duration = max(system_schedule.per_system{sys}.repair_complete_day,[],2); % total repair time spent in this system over all stories
    start_day = repair_complete_day_per_system(:,sys) - system_duration;
    story_start_day = start_day + system_schedule.per_system{sys}.repair_start_day;
    story_complete_day = start_day + system_schedule.per_system{sys}.repair_complete_day;

    % Re-distribute to each tenant unit
    sys_filt = damage.comp_ds_table.system' == systems.id(sys); % identifies which ds idices are in this seqeunce  
    for tu = 1:num_units
        is_damaged = damage.tenant_units{tu}.qnt_damaged(:,sys_filt) > 0;
        is_damaged = is_damaged*1;
        is_damaged(is_damaged == 0) = NaN;

        % Re-distribute repair days to component damage states
        damage.tenant_units{tu}.recovery.repair_start_day(:,sys_filt) = is_damaged .* story_start_day(:,tu);
        damage.tenant_units{tu}.recovery.repair_complete_day(:,sys_filt) = is_damaged .* story_complete_day(:,tu);
    end
end
    
% Post process for temp repairs
for tu = 1:num_units
    % Calculate the day repairs are completed considering temporary repairs
    repair_complete_day_no_NaN = max(damage.tenant_units{tu}.recovery.repair_complete_day,0);
    damage.tenant_units{tu}.recovery.repair_complete_day_w_tmp = min(repair_complete_day_no_NaN, tmp_repair_complete_day);

    % Calculate the day repairs start considering temporary repairs
    damage.tenant_units{tu}.recovery.start_day_w_tmp = damage.tenant_units{tu}.recovery.repair_start_day;
    damage.tenant_units{tu}.recovery.tmp_day_controls = damage.tenant_units{tu}.recovery.repair_complete_day_w_tmp < repair_complete_day_no_NaN;
    damage.tenant_units{tu}.recovery.repair_start_day_w_tmp(damage.tenant_units{tu}.recovery.tmp_day_controls) = 0;

    % Change zeros in complete day back to NaN (ie no damage)
    damage.tenant_units{tu}.recovery.repair_complete_day_w_tmp(damage.tenant_units{tu}.recovery.repair_complete_day_w_tmp == 0) = NaN;
end


end

