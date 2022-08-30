function combined = fn_combine_comp_breakdown(comp_ds_table, perform_targ_days, comp_names, reoccupancy, functional)
% get the combined reoccupancy/functionality effect of components
combined = [];
max_reocc_func = max(reoccupancy, functional);
for c = 1:length(comp_names)
    comp_filt = strcmp(comp_ds_table.comp_id, comp_names{c}); % find damage states associated with this component    
    combined(c,:) = mean(max(max_reocc_func(:,comp_filt'), [], 2) > perform_targ_days);
end

end
