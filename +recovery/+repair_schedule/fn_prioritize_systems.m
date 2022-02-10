function [ sys_idx_priority_matrix ] = fn_prioritize_systems( systems, damage, tmp_repair_complete_day )
% Determine the priority of worker allocation for each system and realization
% based on default table priorities, whether they have the potential to 
% affect function and whether they are resolved by temporary repairs.

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
% initialize variables
num_sys = height(systems);
[num_reals, ~] = size(damage.tenant_units{1}.qnt_damaged);

% Find which components potentially affect function accross any tenant unit
affects_function = zeros(num_reals, length(damage.comp_ds_info.comp_id));
for s = 1:length(damage.tenant_units)
    affects_function = affects_function | (damage.fnc_filters.affects_function & damage.tenant_units{s}.qnt_damaged);
end

% identify component damage that is resolved by temporary repairs
tmp_repaired = tmp_repair_complete_day < inf; % inf here means there is not temp repair
   
%% Define ranks for each system 
sys_affects_function = zeros(num_reals, num_sys); % only prioritize the systems that potentially affect function
sys_tmp_repaired = zeros(num_reals, num_sys); % dont prioitize the systems that are completely resolved by temporary repairs
for sys = 1:num_sys
% <<<<<<< HEAD
% =======
%     affects_function = zeros(num_reals, length(damage.comp_ds_info.comp_id));
%     for s = 1:length(damage.tenant_units)
%         affects_function = affects_function | (damage.fnc_filters.affects_function & damage.tenant_units{s}.qnt_damaged);
%     end
%     
% >>>>>>> update_atc138_attributes
    sys_filter = damage.comp_ds_info.system == sys;
    sys_affects_function(:,sys) = any(affects_function(:,sys_filter),2); % any damage that potentially affects function in this system
    sys_tmp_repaired(:,sys) = all(tmp_repaired(:,sys_filter),2); % all components must be resolved by temp repairs in this system
end
prioritize_system = sys_affects_function & ~sys_tmp_repaired;

sys_priority_matrix = prioritize_system .* (100 + systems.priority') + ~prioritize_system .* (200 + systems.priority'); % the added 200 is just to deprioritize non-function hindering damage

% use rank matrix to get row indeces of priorities
[~, sys_idx_priority_matrix] = sort(sys_priority_matrix, 2);

end

