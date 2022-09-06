function [subsys_repair_day] = fn_calc_subsystem_recovery(subsys_filt, damage, ...
    repair_complete_day, total_num_comps, damaged_comps)
% Check whether the components of a particular subsystem have redundancy
% or not and calculate the day the subsystem recovers opertaions
%
% Parameters
% ----------
% subsys_filt: logical array [1 x num_comps_ds]
%   indentifies which rows in the damage.comp_ds_info are the components of interest
% damage: struct
%   contains per damage state damage, loss, and repair time data for each 
%   component in the building
% repair_complete_day: array [num_reals x num_comps_ds]
%   day reapairs are complete for each components damage state for a given
%   tenant unit
% total_num_comps: array [1 x num_comps_ds]
%   total number of each component damage state in this tenant unit
% damaged_comps: array [num_reals x num_comps_ds]
%   total number of damaged components in each damage state in this tenant unit
%
% Returns
% -------
% subsys_repair_day: array [num reals x 1]
%   The day this subsystem stops affecting functoin in a given tenant unit

%% Initial Setup
[num_reals, ~] = size(repair_complete_day);
is_redundant = max(damage.comp_ds_table.parallel_operation(subsys_filt)); % should all be the same within a subsystem
any_comps = any(subsys_filt);

%% Check if the componet has redundancy
if any_comps
    if is_redundant
        %% go through each component in this subsystem and find number of damaged units
        comps = unique(damage.comp_ds_table.comp_idx(subsys_filt));
        num_tot_comps = zeros(1,length(comps));
        num_damaged_comps = zeros(num_reals,length(comps));
        for c = 1:length(comps)
            this_comp = subsys_filt & (damage.comp_ds_table.comp_idx == comps(c))';
            num_tot_comps(c) = max(total_num_comps .* this_comp); % number of units across all ds should be the same
            num_damaged_comps(:,c) = max(damaged_comps .* this_comp,[],2);
        end

        %% sum together multiple components in this subsystem
        subsystem_num_comps = sum(num_tot_comps);
        subsystem_num_damaged_comps = sum(num_damaged_comps,2);
        ratio_damaged = subsystem_num_damaged_comps ./ subsystem_num_comps;

        %% Check failed component against the ratio of components required for system operation
        % system fails when there is an insufficient number of operating components
        n1_redundancy = max(damage.comp_ds_table.n1_redundancy(subsys_filt)); % should all be the same within a subsystem
        if subsystem_num_comps == 0 % No components at this level
            subsystem_failure = zeros(num_reals,1);
        elseif subsystem_num_comps == 1 % Not actually redundant
            subsystem_failure = subsystem_num_damaged_comps == 0;
        elseif n1_redundancy
            % These components are designed to have N+1 redundncy rates,
            % meaning they are designed to lose one component and still operate at
            % normal level
            subsystem_failure = subsystem_num_damaged_comps > 1;
        else
            % Use a predefined ratio
            redundancy_threshold = max(damage.comp_ds_table.redundancy_threshold(subsys_filt)); % should all be the same within a subsystem
            subsystem_failure = ratio_damaged > redundancy_threshold;
        end

        %% Calculate recovery day and combine with other subsystems for this tenant unit
        % assumes all quantities in each subsystem are repaired at
        % once, which is true for our current repair schedule (ie
        % system level at each story)
        subsys_repair_day = max(subsystem_failure .* subsys_filt .* repair_complete_day,[],2); 
    else % This subsystem has no redundancy
        % any major damage to the components fails the subsystem at this
        % tenant unit
        subsys_repair_day = max(repair_complete_day .* subsys_filt,[],2);
    end
else % No components were populated in this subsystem
    subsys_repair_day = zeros(num_reals,1);
end

end % Function