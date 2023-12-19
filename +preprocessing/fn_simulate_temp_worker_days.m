function [ damage, temp_repair_class ] = fn_simulate_temp_worker_days( damage, temp_repair_class, repair_time_options )
% Simulate Temporary Repair Times for each component, if not already
% defined by the user. In a perfect system this should be done alongside 
% the other full repair time simulation. However, most PBEE assessments do
% not contain information on temp repair times per component when they are
% simulating damage and consequences. Therefore, this is decoupled from the
% rest of the assessment and simulated here (if not already provided by the
% user)
%
% Parameters
% ----------
% damage: struct
%   contains simulated damage info and damage state attributes
% repair_time_options.allow_shoring: logical
%   flag indicating whether or not shoring should be considered as a
%   temporary repair for local stability issues for structural components
% temp_repair_class: table
%   attributes of each temporary repair class to consider
%
% Returns
% -------
% damage: struct
%   contains simulated damage info and damage state attributes
% temp_repair_class: table
%   attributes of each temporary repair class to consider
%

%% Define Temporary Repair Times Options
% Turn of temp repairs if specificied by the user
if ~repair_time_options.allow_tmp_repairs
    damage.comp_ds_table.tmp_repair_class = zeros(size(damage.comp_ds_table.tmp_repair_class));
end

% Set up temp_repair_class based on user inputs
if ~repair_time_options.allow_shoring
    temp_repair_class(temp_repair_class.id == 5,:) = []; % Remove shoring from table
end

%% Simulate temp repair worker days per component 
% if not already specified by the user
if ~isfield(damage.tenant_units{1},'tmp_worker_day')
    % Find total number of damamged components
    total_damaged = damage.tenant_units{1}.qnt_damaged;
    for tu = 2:length(damage.tenant_units)
        total_damaged = total_damaged + damage.tenant_units{tu}.qnt_damaged;
    end

    % Aggregate the total number of damaged components accross each damage
    % state in a component
    tmp_worker_days_per_unit = [];
    for c = 1:height(damage.comp_ds_table) % for each comp ds
        comp = damage.comp_ds_table(c,:);
        if comp.tmp_repair_class > 0 % For damage that has temporary repair
            filt = strcmp(damage.comp_ds_table.comp_id,comp.comp_id)';
            total_damaged_all_ds = sum(total_damaged(:,filt),2);

            % Interpolate to get per unit temp repair times
            if comp.tmp_repair_time_lower_qnty == comp.tmp_repair_time_upper_qnty
                tmp_worker_days_per_unit(:,c) = comp.tmp_repair_time_lower;
            else
                tmp_worker_days_per_unit(:,c) = ...
                    interp1([comp.tmp_repair_time_lower_qnty, comp.tmp_repair_time_upper_qnty],...
                            [comp.tmp_repair_time_lower,comp.tmp_repair_time_upper],...
                            min(max(total_damaged_all_ds,comp.tmp_repair_time_lower_qnty),comp.tmp_repair_time_upper_qnty));
            end

        else
            tmp_worker_days_per_unit(:,c) = NaN(size(total_damaged(:,1)));
        end
    end

    % Simulate uncertainty in per unit temp repair times
    % Assumes distribution is lognormal with beta = 0.4
    % Assumes time to repair all of a given component group is fully correlated, 
    % but independant between component groups 
    sim_tmp_worker_days_per_unit = lognrnd(log(tmp_worker_days_per_unit),0.4,size(tmp_worker_days_per_unit));

    % Allocate per unit temp repair time among tenant units to calc worker days
    % for each component
    for tu = 1:length(damage.tenant_units)
        damage.tenant_units{tu}.tmp_worker_day = ...
            damage.tenant_units{tu}.qnt_damaged .* sim_tmp_worker_days_per_unit;
    end
end

end

