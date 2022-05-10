function [] = plt_recovery_trajectory( recovery, full_repair_time, plot_dir)
% Plot mean recovery trajectories
%
% Parameters
% ----------
% recovery: structure
%   data structure containing recovery trajectory data from the functional
%   recovery assessment
% full_repair_time: array [num reals x 1] 
%   simulated realization of full repair time 
% plot_dir: str
%   Save directory for plots. Plots will save directly to this location as
%   png files.
%
% Returns
% -------
% 

%% Initial Setup
if ~exist(plot_dir,'dir')
    mkdir(plot_dir)
end

% Calculate mean recovery times
reoc = mean(recovery.reoccupancy.recovery_trajectory.recovery_day);
func = mean(recovery.functional.recovery_trajectory.recovery_day);
full = mean(full_repair_time);
level_of_repair = recovery.functional.recovery_trajectory.percent_recovered;

%% Plot Recovery Trajectory
hold on 
plot(reoc, level_of_repair,'r','LineWidth',1.5,'DisplayName','Re-Occupancy') 
plot(func, level_of_repair,'b','LineWidth',1.5,'DisplayName','Functional') 
plot([full full], [0 1],'k','LineWidth',1.5,'DisplayName','Fully Repaired') 
xlim([0,ceil((full+1)/10)*10])
xlabel('Days After Earthquake')
ylabel('Fraction of Floor Area')
box on
grid on
legend('location', 'Northwest');
set(gca,'fontname','times')
set(gcf,'position',[10,10,500,300])
saveas(gcf,[plot_dir filesep 'recovery trajectory'],'png')
close

end

