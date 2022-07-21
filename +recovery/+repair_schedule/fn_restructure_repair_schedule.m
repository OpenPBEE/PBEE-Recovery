function [ damage ] = fn_restructure_repair_schedule( damage, system_schedule, ...
    repair_complete_day_per_system, systems, repair_type, simulated_red_tags)
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
% In the repair start day outputs:
%    - Zero = Starts immediately
%    - NaN = Repairs never started (likely because not damaged or has no temp repair)
% In the repair complete day outputs:
%    - NaN = No damage
%    - Inf = Is damaged, but has no System/RepairClass assignment (or no temp repair)
% 

%% Initialize Parameters
num_sys = height(systems);
num_units = length(damage.tenant_units);

% Define Repair Type Variables (variable within the damage object)
if strcmp(repair_type,'full')
    system_var = 'system';
elseif strcmp(repair_type,'temp')
    system_var = 'tmp_repair_class';
else
    error('Unexpected Repair Type')
end

% Initialize recovery field
for tu = 1:num_units
    % Set to inf as a null repair time (will remain inf for components with
    % no attributed system) - matters for temp repairs, shouldnt matter for
    % full repair
    damage.tenant_units{tu}.recovery.repair_start_day = nan(size(damage.tenant_units{tu}.qnt_damaged));
    damage.tenant_units{tu}.recovery.repair_complete_day = inf(size(damage.tenant_units{tu}.qnt_damaged));
    
    % if not damaged, set repair complete time to NaN
    is_damaged = damage.tenant_units{tu}.qnt_damaged > 0;
    damage.tenant_units{tu}.recovery.repair_complete_day(~is_damaged) = NaN; 
end

%% Redistribute repair schedule data
for sys = 1:num_sys
    % Calculate system repair times on each story
    system_duration = max(system_schedule.per_system{sys}.repair_complete_day,[],2); % total repair time spent in this system over all stories
    start_day = repair_complete_day_per_system(:,sys) - system_duration;
    story_start_day = start_day + system_schedule.per_system{sys}.repair_start_day;
    story_complete_day = start_day + system_schedule.per_system{sys}.repair_complete_day;
    
    % Do not perform temporary repairs when building is red tagged
    if strcmp(repair_type,'temp')
        story_start_day(simulated_red_tags,:) = NaN;
        story_complete_day(simulated_red_tags,:) = Inf;
    end

    % Re-distribute to each tenant unit
    sys_filt = damage.comp_ds_table.(system_var)' == systems.id(sys); % identifies which ds idices are in this seqeunce  
    for tu = 1:num_units
        is_damaged = damage.tenant_units{tu}.qnt_damaged(:,sys_filt) > 0;
        is_damaged = is_damaged*1;
        is_damaged(is_damaged == 0) = NaN;

        % Re-distribute repair days to component damage states
        damage.tenant_units{tu}.recovery.repair_start_day(:,sys_filt) = is_damaged .* story_start_day(:,tu);
        damage.tenant_units{tu}.recovery.repair_complete_day(:,sys_filt) = is_damaged .* story_complete_day(:,tu);
        
    end
end

end

