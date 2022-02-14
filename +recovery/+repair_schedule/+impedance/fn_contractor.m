function contractor_mob_imped = fn_contractor( num_sys, num_reals, ...
    surge_factor, sys_repair_trigger, systems, is_contractor_on_retainer )
% Simulute contractor mobilization time
%
% Parameters
% ----------
% num_sys: int
%   number of building systems considered in the assessment
% num_reals: int
%   number of Monte Carlo simulations assessed
% surge_factor: number
%   amplification factor for impedance time based on a post disaster surge
%   in demand for skilled trades and construction supplies
% sys_repair_trigger: logical array [num_reals x num_systems]
%   systems that require repair for each realization
% systems: table
%   data table containing information about each system's attributes
% is_contractor_on_retainer: logical
%   is there a pre-arranged agreement with a contractor for priorization of repairs
%
% Returns
% -------
% contractor_mob_imped: array [num_reals x num_sys]
%   Simulated contractor mobilization time for each system

%% Define financing distribution parameters
if is_contractor_on_retainer
    contr_min = surge_factor * systems.imped_contractor_min_days';
    contr_max = surge_factor * systems.imped_contractor_max_days';
else
    contr_min = surge_factor * systems.imped_contractor_min_days_retainer';
    contr_max = surge_factor * systems.imped_contractor_max_days_retainer';
end

%% Simulate 
% uniform distribution between min and max
% This assumes systems are independant
contractor_mob_imped = unifrnd(contr_min.*ones(num_reals,1),...
    contr_max.*ones(num_reals,1),num_reals,num_sys);

% Only use the simulated values for the realzation and system that
% require permitting
contractor_mob_imped(~sys_repair_trigger) = 0;

% Amplify by the surge factor
% Assume impedance always takes a full day
contractor_mob_imped = ceil(contractor_mob_imped);

end

