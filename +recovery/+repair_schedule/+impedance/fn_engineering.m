function [ eng_mob_imped, design_imped ] = fn_engineering( ...
    surge_factor, system_design_time, design_min, design_max, trunc_pd )
% Simulute permitting time
%
% Parameters
% ----------
% surge_factor: number
%   amplification factor for impedance time based on a post disaster surge
%   in demand for skilled trades and construction supplies
% system_design_time: array [num_reals x num_systems]
%   portion of system repair time that requires redesign 
% trunc_pd: matlab normal distribution object
%   standard normal distrubtion, truncated at upper and lower bounds
% design_min: row vector [1 x n_systems]
%   lower bound on the median for each system
% design_max: row vector [1 x n_systems]
%   upper bound on the median for each system
%
% Returns
% -------
% eng_mob_imped: array [num_reals x num_sys]
%   Simulated enginering mobilization time for each system
% design_imped: array [num_reals x num_sys]
%   Simulated enginering design time for each system

% Notes
% ------
% assumes both engineering mobilization and re-design time are independant
% for each system. In other words, you will have different designers for
% the structural, stairs, exterior, and whatever other systems need design
% time. Now this may be incorrect and need to be changed to one design time
% for all systems (or one mobilization time and multiple design times)

%% Initial Setup
[num_reals, num_sys] = size(system_design_time);

%% Engineering Mobilization Time
% Median mobilizaiton times for each system
median_eng_mob = zeros(1, num_sys);
median_eng_mob(1) = 4 * 7; % 4 weeks for structure
median_eng_mob(2) = 2 * 7; % two weeks for exterior
median_eng_mob(4) = 2 * 7; % two weeks for stairs

% Truncated lognormal distribution (via standard normal simulation)
beta = 0.6;
prob_sim = rand(num_reals, 1); % This assumes systems are correlated
x_vals_std_n = icdf(trunc_pd, prob_sim);
eng_mob_time = exp(x_vals_std_n * beta + log(median_eng_mob));
redesign_trigger = system_design_time > 0;
eng_mob_time(~redesign_trigger) = 0;

% Multiply by surge factor and save in data structure
eng_mob_imped = surge_factor * eng_mob_time;

%% Engineering Design Time
design_med = min(max(system_design_time, design_min), design_max);

% Truncated lognormal distribution (via standard normal simulation)
beta = 0.6;
prob_sim = rand(num_reals,1); % This assumes systems are correlated
x_vals_std_n = icdf(trunc_pd ,prob_sim);
eng_design_time = exp(x_vals_std_n * beta + log(design_med));
eng_design_time(~redesign_trigger) = 0;

% Multiply by surge factor and save in data structure
design_imped = surge_factor * eng_design_time;

end

