function [ system_design_time, permit_review_time, system_rapid_permit_trigger ] = fn_calculate_sdt_prt( ...
    damage, system_repair_time )
% Calculate system design time (SDT) and permit review time (PRT) based on system repair time
%
% Parameters
% ----------
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% system_repair_time [num reals x num systems]
%   The number of days required to repair each system in isolation
%
% Returns
% -------
% system_design_time: array [num reals x num systems]
%   The system repair time proportional to the repairs that require
%   redesign
% permit_review_time: array [num reals x num systems]
%   The system repair time proportional to the repairs that require
%   permitting
% system_rapid_permit_trigger: logical array [num reals x num systems]
%   Simulation of systems that require rapid permits
%
% Notes
% -----


%% Initialize Variables
[num_reals, num_sys] = size(system_repair_time);
system_worker_days = zeros(num_reals, num_sys);
system_worker_days_redesign = zeros(num_reals, num_sys);
system_worker_days_permit = zeros(num_reals, num_sys);
system_rapid_permit_trigger = zeros(num_reals, num_sys);
redesign = damage.comp_ds_info.redesign == 1;
permiting = damage.comp_ds_info.full_permit == 1;
rapid_permit = damage.comp_ds_info.rapid_permit == 1;

%% Parse damage object data for worker day ratios
for sys = 1:num_sys
    sys_filt = damage.comp_ds_info.system == sys; 
    for s = 1:length(damage.story)
        % Track cummulative worker days per system
        system_worker_days(:,sys) = system_worker_days(:,sys) ...
            + sum(damage.story{s}.worker_days(:,sys_filt), 2);
        system_worker_days_redesign(:,sys) = system_worker_days_redesign(:,sys) ...
            + sum(damage.story{s}.worker_days(:,sys_filt & redesign),2);
        system_worker_days_permit(:,sys) = system_worker_days_permit(:,sys) ...
            + sum(damage.story{s}.worker_days(:,sys_filt & permiting),2);
        
        % Track if any damage exists that requires rapid permit per system
        is_damaged = damage.story{s}.qnt_damaged > 0;
        system_rapid_permit_trigger(:,sys) = max( ...
            system_rapid_permit_trigger(:,sys), ...
            max(is_damaged .* (sys_filt & rapid_permit), [], 2) ...
        );
    end
end

%% Calculate SDT and PRT
% System design time equals the system repair times times the ratio of
% total system worker days with redesign flags
system_design_time = system_repair_time .* (system_worker_days_redesign ./ system_worker_days);
system_design_time(isnan(system_design_time)) = 0;

% Permit review time equals the system repair times times the ratio of
% total system worker days with full permit flags
permit_review_time = system_repair_time .* (system_worker_days_permit ./ system_worker_days);
permit_review_time(isnan(permit_review_time)) = 0;

end

