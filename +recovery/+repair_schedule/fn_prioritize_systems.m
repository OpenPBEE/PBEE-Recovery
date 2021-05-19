function [ sys_idx_priority_matrix ] = fn_prioritize_systems( systems, damage )
% Determine the priority of worker allocation for each system and realization
%
% Parameters
% ----------
% systems: table
%   data table containing information about each system's attributes
% damage: struct
%   contains per damage state damage and loss data for each component in the building
%
% Returns
% -------
% sys_idx_priority_matrix: index array [num reals x num systems]
%   row index to filter system matrices to be prioritized for each
%   realiztion. Priority is left to right.

%% Initial Setup
% initialize variables
num_sys = height(systems);
[num_reals, ~] = size(damage.story{1}.qnt_damaged);

%% Define ranks for each system 
% based on default table priorities and whether or not they have the potential to affect function
sys_affects_function = zeros(num_reals, num_sys);
for sys = 1:num_sys
    affects_function = zeros(num_reals, length(damage.comp_ds_info.comp_id));
    for s = 1:length(damage.story)
        affects_function = affects_function | (damage.comp_ds_info.affects_function & damage.story{s}.qnt_damaged);
    end
    
    sys_filter = damage.comp_ds_info.system == sys;
    sys_affects_function(:,sys) = any(affects_function(:,sys_filter),2);
end
sys_priority_matrix = sys_affects_function .* (100 + systems.priority') + ~sys_affects_function .* (200 + systems.priority'); % the added 200 is just to deprioritize non-function hindering damage

% use rank matrix to get row indeces of priorities
[~, sys_idx_priority_matrix] = sort(sys_priority_matrix, 2);

end

