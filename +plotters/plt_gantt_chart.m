function [] = plt_gantt_chart( p_idx, recovery, full_repair_time, workers, schedule, impede, plot_dir, plot_name )
% Plot gantt chart for a single realization of the functional recovery
% assessment
%
% Parameters
% ----------
% p_idx: int
%   realization index of interest
% recovery: structure
%   data structure containing recovery trajectory data from the functional
%   recovery assessment
% full_repair_time: array [num reals x 1] 
%   simulated realization of full repair time 
% workers: structure
%   data structure containing work allocation data from the functional
%   recovery assessment
% schedule: structure
%   data structure containing repair schedule data from the functional
%   recovery assessment
% impede: structure
%   data structure containing impedance time data from the functional
%   recovery assessment
% plot_dir: str
%   Save directory for plots. Plots will save directly to this location as
%   png files.
% plot_name: str
%   name of file to save plot as (does not include the file type extension)
%
% Returns
% -------
% 
%% Intial Setup
if ~exist(plot_dir,'dir')
    mkdir(plot_dir)
end

imps = fieldnames(impede);
sys = fieldnames(impede.contractor_mob);

%% Format Gantt Chart Data
% Collect Recovery Trajectory
recovery_trajectory.reoc = recovery.reoccupancy.recovery_trajectory.recovery_day(p_idx,:);
recovery_trajectory.func = recovery.functional.recovery_trajectory.recovery_day(p_idx,:);
recovery_trajectory.level_of_repair = recovery.reoccupancy.recovery_trajectory.percent_recovered;
recovery_trajectory.ful_rep = ones(1,length(recovery_trajectory.level_of_repair)) * ceil(full_repair_time(p_idx));

% Collect Worker Data
worker_data.total_workers = workers.total_workers(p_idx,:);
worker_data.day_vector = workers.day_vector(p_idx,:);

% Collect Impedance Times
sys_imp_times = [];
labs = [];
for s = 1:length(sys)
    for i = 1:length(imps)
        if isfield(impede.(imps{i}),'complete_day')
            duration = impede.(imps{i}).complete_day(p_idx) - impede.(imps{i}).start_day(p_idx);
            if duration > 0
                sys_imp_times(i,:) = [impede.(imps{i}).start_day(p_idx), duration];
                labs{i} = [upper(imps{i}(1)) strrep(imps{i}(2:end),'_',' ')];
            end
        elseif isfield(impede.(imps{i}),sys{s})
            duration = impede.(imps{i}).(sys{s}).complete_day(p_idx) - impede.(imps{i}).(sys{s}).start_day(p_idx);
            if duration > 0
                sys_imp_times(end+1,:) = [impede.(imps{i}).(sys{s}).start_day(p_idx), duration];
                labs{end+1} = [upper(sys{s}(1)) sys{s}(2:end) ' ' strrep(imps{i},'_',' ')];
            end
        end
    end
end
labs_imp = flip(labs);
y_imp = flip(sys_imp_times);

% Collect Repair Times 
sys_repair_times = [];
labs = [];
for s = 1:length(sys) % WARNING: This assumes the system order in the output of repair schedule is the same order has the impedance breakdowns
    duration = schedule.repair_complete_day.per_system(p_idx,s) - schedule.repair_start_day.per_system(p_idx,s);
    if duration > 0
        sys_repair_times(end+1,:) = [schedule.repair_start_day.per_system(p_idx,s),duration];
        labs{end+1} = [upper(sys{s}(1)) sys{s}(2:end) ' Repairs'];
    end
end
labs_rep = flip(labs);
y_rep = flip(sys_repair_times);

%% Plot Gantt
x_limit = max(ceil(max(recovery_trajectory.ful_rep)/10)*10,1);

% Set Plot Layout
pos = [0.25    0.63     0.7    0.34;...
       0.25    0.41     0.7    0.19;...
       0.25    0.24     0.7    0.14;...
       0.25    0.065    0.7    0.14];

% Impedance Time
subplot('Position',pos(1,:))
x = categorical(labs_imp);
x = reordercats(x,labs_imp);
G = barh(x,y_imp,'stacked');
G(1).HandleVisibility = 'off';
G(2).DisplayName = 'Repair Time';
set(G(1),'Visible','off')
G(2).FaceColor = [0.6, 0.6, 0.6];
G(2).FaceAlpha = 0.5;
G(2).EdgeAlpha = 0;
% set(gca,'YColor','k')
fn_format_subplot(gca,x_limit,[],[],'Impedance Time')

% Repair Time
subplot('Position',pos(2,:))
x = categorical(labs_rep);
x = reordercats(x,labs_rep);
H = barh(x,y_rep,'stacked');
H(1).HandleVisibility = 'off';
H(2).DisplayName = 'Repair Time';
set(H(1),'Visible','off')
H(2).FaceColor = [0.1, 0.1, 0.1];
H(2).FaceAlpha = 0.5;
H(2).EdgeAlpha = 0;
% set(gca,'YColor','k')
fn_format_subplot(gca,x_limit,[],[],'Repair Time')

% Workers
subplot('Position',pos(3,:))
hold on
plot(worker_data.day_vector, worker_data.total_workers)
fn_format_subplot(gca,x_limit,{'Number of', 'Workers'},[],'Workers')

% Plot Recovery Trajectory
subplot('Position',pos(4,:))
hold on
plot(recovery_trajectory.reoc, recovery_trajectory.level_of_repair,'-r','LineWidth',1.5,'DisplayName','Re-Occupancy')
plot(recovery_trajectory.func, recovery_trajectory.level_of_repair,'-b','LineWidth',1.5,'DisplayName','Functional')
plot(recovery_trajectory.ful_rep, recovery_trajectory.level_of_repair,'-k','LineWidth',1.5,'DisplayName','Fully Repaired')
ylim([0,1])
lgd = legend('location','northeast');
set(lgd,'position',[0.07    0.11    0.05   0.05])
fn_format_subplot(gca,x_limit,'Fraction of Floor Area','Days After Earthquake','Building Recovery State')

% Set and Save plot
set(gcf,'position',[10,10,800,600])
saveas(gcf,[plot_dir filesep plot_name],'png')
close

end

function [] = fn_format_subplot(ax,x_limit,y_lab,x_lab,tle)
    ax.XGrid = 'on';
    ax.XMinorGrid = 'on';
    xlim([0,x_limit])
    box on
    set(gca,'fontname','times')
    set(gca,'fontsize',9)
    if ~isempty(y_lab)
        ylabel(y_lab)
    end
    if ~isempty(x_lab)
        xlabel(x_lab)
    else
        set(gca,'XTickLabel',[])
    end
    title(tle)
end