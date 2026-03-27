function [ sys_idx_priority_matrix ] = fn_prioritize_systems( systems, repair_type, damage, tmp_repair_complete_day, impeding_factors )
% Determine the priority of worker allocation for each system and realization
% based on default table priorities, whether they have the potential to 
% affect reoccupancy or function and whether they are resolved by 
% temporary repairs.

% Parameters
% ----------
% systems: table
%   data table containing information about each system's attributes
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% tmp_repair_complete_day: array [num_reals x num_comp]
%   contains the day (after the earthquake) the temporary repair time is 
%   resolved per damage state damage and realization. Inf represents that
%   there is not temporary repair time available for a given components
%   damage.
%
% Returns
% -------
% sys_idx_priority_matrix: index array [num reals x num systems]
%   row index to filter system matrices to be prioritized for each
%   realiztion. Priority is left to right.
% 
% Notes
% ------
% The checks done here are only able to implicitly check for which systems
% affect funtion the most (this prioritizes which have the potential to
% affect function). To explicitly check which systems have the biggest
% impact on function and prioritize those, this check would need to be
% coupled with the function assessment

%% Initial Setup
% Define Repair Type Variables (variable within the damage object)
if strcmp(repair_type,'full')
    system_var = 'system';
elseif strcmp(repair_type,'temp')
    system_var = 'tmp_repair_class';
else
    error('Unexpected Repair Type')
end

% initialize variables
num_sys = height(systems);
[num_reals, ~] = size(damage.tenant_units{1}.qnt_damaged);

% Find which components potentially affect reoccupancy accross any tenant unit
affects_reoccupancy = zeros(num_reals, height(damage.comp_ds_table));
for s = 1:length(damage.tenant_units)
    affects_reoccupancy = affects_reoccupancy | (damage.fnc_filters.affects_reoccupancy & damage.tenant_units{s}.qnt_damaged);
end

% Find which components potentially affect function accross any tenant unit
affects_function = zeros(num_reals, height(damage.comp_ds_table));
for s = 1:length(damage.tenant_units)
    affects_function = affects_function | (damage.fnc_filters.affects_function & damage.tenant_units{s}.qnt_damaged);
end

%% Define ranks for each system 
sys_affects_reoccupancy = zeros(num_reals, num_sys); % only prioritize the systems that potentially affect function
sys_affects_function = zeros(num_reals, num_sys); % only prioritize the systems that potentially affect function
sys_tmp_repaired = zeros(num_reals, num_sys); % dont prioitize the systems that are completely resolved by temporary repairs
for sys = 1:num_sys
    sys_filter = damage.comp_ds_table.(system_var)' == sys;
    if any(sys_filter) % Only if this system is present
        sys_affects_reoccupancy(:,sys) = any(affects_reoccupancy(:,sys_filter),2); % any damage that potentially affects reoccupancy in this system
        sys_affects_function(:,sys) = any(affects_function(:,sys_filter),2); % any damage that potentially affects function in this system
        if ~isempty(tmp_repair_complete_day) % Only if temp repair data is passed in
            all_sys_tmp_repaired = all(tmp_repair_complete_day(:,sys_filter)<inf | isnan(tmp_repair_complete_day(:,sys_filter)),2); % is every single damaged component resolved by temp repairs
            tmp_repair_quick = max(tmp_repair_complete_day(:,sys_filter),[],2) < impeding_factors.time_sys(:,sys); % Are the temp repairs for this system resolved before impeding factors are complete
            sys_tmp_repaired(:,sys) = all_sys_tmp_repaired & tmp_repair_quick; % damage is quickly resolved by temp repair
        end
    end
end
prioritize_system_reoccupancy = sys_affects_reoccupancy & ~sys_tmp_repaired;
prioritize_system_function_only = sys_affects_function & ~prioritize_system_reoccupancy & ~sys_tmp_repaired;
non_priorities = ~prioritize_system_reoccupancy & ~prioritize_system_function_only;

sys_priority_matrix = prioritize_system_reoccupancy   .* (100 + systems.priority') + ... % First prioritize reoccpancy repairs (100 classifies first priority bank, important for sort function below)
                      prioritize_system_function_only .* (200 + systems.priority') + ... % then priotize repairs that only affect function (200 classifies second priority bank)
                      non_priorities                  .* (300 + systems.priority'); % finally, repair the systems that dont affect reoccupancy or function (300 classifies third priority bank)

% use rank matrix to get row indeces of priorities
[~, sys_idx_priority_matrix] = sort(sys_priority_matrix, 2);

end

