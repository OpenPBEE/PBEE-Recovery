function combined = fn_combine_comp_breakdown(comp_ds_table, perform_targ_days, comp_names, reoccupancy, functional)
% get the combined reoccupancy/functionality effect of components
%
% Parameters
% ----------
% comp_ds_table: table
%   contains basic component attributes
% perform_targ_days: array
%   recovery time horizons to consider
% comp_names: cell array
%   string ids of components to attribte recovery time to
% reoccupancy: array [num reals x num comp_ds]
%   realizations of reoccupancy time broken down for each damage state of
%   each component
% functional: array [num reals x num comp_ds]
%   realizations of functional recovery time broken down for each damage
%   state of each component
%
% Returns
% -------
% combined: array
%   Probability of recovering within time horizon for each component
%   considering both consequenses from reoccupancy and functional recovery

%% Method
combined = zeros(length(comp_names),length(perform_targ_days));
max_reocc_func = max(reoccupancy, functional);
for c = 1:length(comp_names)
    comp_filt = strcmp(comp_ds_table.comp_id, comp_names{c}); % find damage states associated with this component    
    combined(c,:) = mean(max(max_reocc_func(:,comp_filt'), [], 2) > perform_targ_days,1);
end

end
