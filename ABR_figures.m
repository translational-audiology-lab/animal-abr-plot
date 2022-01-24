%% Add data to path
addpath('data/');

%calculate sample rate and time vector based on 19.985ms (0.019985 sec) in 488 samples

%Fs = 488/0.019985; = 24 418

% 19.985/488 = 0.0410, i.e time per sample

timevec = [0:0.0410:19.985]; %in ms

%% Import key from text file and initialize variables (auto generated)

%Initialize variables.
filename = 'id_key.txt';
delimiter = '\t';
startRow = 2;

%Format string for each line of text:
formatSpec = '%f%s%s%s%[^\n\r]';

%Open the text file.
fileID = fopen(filename,'r');

%Read columns of data according to format string.
dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false);

%Close the text file.
fclose(fileID);

%Post processing for unimportable data.
%Allocate imported array to column variable names
ID = dataArray{:, 1};
group = dataArray{:, 2};
gen = dataArray{:, 3};
vir = dataArray{:, 4};

%Clear temporary variables
clearvars filename delimiter startRow formatSpec fileID dataArray ans;

%% Gather data

ABR = struct();

%For each ID
for ii = 1:length(ID)
    
    %If ID has file in data
    if ~isempty(dir(['data/' num2str(ID(ii)) '*.txt']))
        
        %Get full filname
        fname = dir(['data/' num2str(ID(ii)) '*.txt']);
        fname = fname.name;
        
        %Load data - open file and put all "cells" in vector by textscan
        fid = fopen(fname, 'r');
        dat = textscan(fid, '%s'); %Easier without 'Delimiter', '\n'
        fclose(fid);
        dat = dat{1};

        %Find indices of Level to use as anchor
        lvlidx = find(ismember(dat, 'Level'));

            for i = 1:length(lvlidx)

               %Extract signal vector (20:488+20) following level index
               for iii = 1:488
                   tempvec(iii) = str2num(dat{lvlidx(i)+19+iii});
               end
               
               %Write to struct under group and stim level (level index + 2)
               ABR.(group{ii}).(['stim' dat{lvlidx(i)+2}])(ii,:) = tempvec
               
               %Remove zeros created by incrementing row by ID (ii)
               a = ABR.(group{ii}).(['stim' dat{lvlidx(i)+2}]);
               ABR.(group{ii}).(['stim' dat{lvlidx(i)+2}]) = a(any(a,2),:);
               
               clear a
               
            end %for lvlidx
            
    end %if file exist
    
end %for ID

%uncomment to save
%save('ABR_vectors.mat', 'ABR');

%% Load and set parameters

%uncomment to load
%ABR = load('ABR_vectors.mat');
%ABR = ABR.ABR;

%Get group names from ABR struct
groups = fieldnames(ABR);

%Offset between ABR traces in graphs
offset = -10*10^-7;

%Reorder stimlevels for wtglut
ABR.wtglut = orderfields(ABR.wtglut, ABR.wtcsf);

%Fill KOCSF to have same n of fields (stim levels) as others
ABR.kocsf.stim45 = [];
ABR.kocsf.stim40 = [];
ABR.kocsf.stim35 = [];
ABR.kocsf.stim30 = [];
ABR.kocsf.stim25 = [];
ABR.kocsf.stim20 = [];
ABR.kocsf.stim15 = [];
ABR.kocsf.stim10 = [];
ABR.kocsf.stim5 = [];
ABR.kocsf.stim0 = [];

%Remove fields we are not interested in
ABR.kocsf = rmfield(ABR.kocsf, {'stim85', 'stim75', 'stim65', 'stim55', 'stim45', 'stim35', 'stim25', 'stim15', 'stim5', 'stim0'});
ABR.wtcsf = rmfield(ABR.wtcsf, {'stim85', 'stim75', 'stim65', 'stim55', 'stim45', 'stim35', 'stim25', 'stim15', 'stim5', 'stim0'});
ABR.koglut = rmfield(ABR.koglut, {'stim85', 'stim75', 'stim65', 'stim55', 'stim45', 'stim35', 'stim25', 'stim15', 'stim5', 'stim0'});
ABR.wtglut = rmfield(ABR.wtglut, {'stim85', 'stim75', 'stim65', 'stim55', 'stim45', 'stim35', 'stim25', 'stim15', 'stim5', 'stim0'});

% Calculate TOI per stim level

%Looked up corresponding samples for TOI in timevec. Round to have same
%stepsize while moving through ten stim levels 90-10.

% W1 90: 1.0 - 1.5 ms, 25 - 37
% W1 10: 1.7 - 2.2 ms, 42 - 54
% W1 onset: 25:2:42
% W1 offset: 37:2:54
% 
% W3 90: 2.7 - 3.7 ms, 67 - 91
% W3 10: 3.6 - 4.6 ms, 89 - 113
% W3 onset: round(67:2.7:91, 0)
% W3 onset: round(89:2.7:113, 0)
% 
% W5 90: 5.5 - 6.5 ms, 135 - 159
% W5 10: 6.5 - 7.5 ms, 160 - 184
% W5 onset: round(135:2.7:159,0)
% W5 offset: round(160:2.7:184,0)

w1on = 25:2:42;
w1off = 37:2:54;
w3on = round(67:2.7:91, 0);
w3off = round(89:2.7:113, 0);
w5on = round(135:2.7:159,0);
w5off = round(160:2.7:184,0);

%% Plot ABR trace and quantify amplitudes and latencies

%struct for amp and lat quantified values
amplat = struct();

fig = figure('Position', [100 150 1100 400]); hold on;
for i = 1:numel(groups)
  
  stims = fieldnames(ABR.(groups{i})); %list of stim-levels
  nstims = length(stims);              %n of stim-levels
  
  %Decide where to put subplots for each group
  if strcmp(groups{i}, 'wtcsf');
      subpos = 2;
  elseif strcmp(groups{i}, 'wtglut');
      subpos = 1;
  elseif strcmp(groups{i}, 'kocsf');
      subpos = 4;
  elseif strcmp(groups{i}, 'koglut');
      subpos = 3;
  end

  
  %Set group color
  fillcol = [0 1 0]; %Green (WT)
  if i <3
      fillcol = [1 0 0]; %Red (KO)
  end
  
  for ii = 1:nstims %Stim levels
       
       tempdat = ABR.(groups{i}).(stims{ii}); %isolate data for stim
       
       %find max and min per row (subject) for stim-level
       for iii = 1:size(tempdat, 1)
           
           %find max between w1on and w1off idx for stim level
           tempmaxw1 = max(tempdat(iii,w1on(ii):w1off(ii)));
           %index I for max and find latency in ms from timevec
           [M, I] = max(tempdat(iii,w1on(ii):w1off(ii)));
           lat1 = timevec(w1on(ii) + I - 1); %indices should start at 0
           
           %repeat for wave 3 and 5 (w3on/off and w5on/off)
           tempmaxw3 = max(tempdat(iii,w3on(ii):w3off(ii)));
           [M, I] = max(tempdat(iii,w3on(ii):w3off(ii)));
           lat3 = timevec(w3on(ii) + I - 1);
           
           tempmaxw5 = max(tempdat(iii,w5on(ii):w5off(ii)));
           [M, I] = max(tempdat(iii,w5on(ii):w5off(ii)));
           lat5 = timevec(w5on(ii) + I - 1);

           tempminw1 = min(tempdat(iii,w1on(ii):w1off(ii)));
           tempminw3 = min(tempdat(iii,w3on(ii):w3off(ii)));
           tempminw5 = min(tempdat(iii,w5on(ii):w5off(ii)));
           
           amp1 = tempmaxw1 - tempminw1;
           amp3 = tempmaxw3 - tempminw3;
           amp5 = tempmaxw5 - tempminw5;
           
           amplat.([groups{i} '_amp_w1'])(iii, ii) = amp1;
           amplat.([groups{i} '_lat_w1'])(iii, ii) = lat1;
           
           amplat.([groups{i} '_amp_w3'])(iii, ii) = amp3;
           amplat.([groups{i} '_lat_w3'])(iii, ii) = lat3;
           
           amplat.([groups{i} '_amp_w5'])(iii, ii) = amp5;
           amplat.([groups{i} '_lat_w5'])(iii, ii) = lat5;
           
       end
       clear amp1 amp3 amp5 lat1 lat3 lat5 I M tempmax* tempmin*
       
       avgabr = mean(tempdat, 1);            %calculate mean
       
       disp(stims{ii}); %display to inspect order
       
       stderror = std(tempdat/sqrt(size(tempdat, 1))); %calculate SEM
       sempos = avgabr + stderror; %calculate positive SEM
       semneg = avgabr - stderror; %calculate negative SEM
       
       subplot(1,4,subpos); hold on;
       
       x2 = [1:length(tempdat), fliplr(1:length(tempdat))];
       inBetween = [sempos + ii * offset, fliplr(semneg + ii * offset)];
       fill(x2, inBetween, fillcol, 'faceAlpha', 0.5, 'EdgeColor', [0.5 0.5 0.5]); %, 'LineStyle', 'none'
       
       plot(avgabr + ii*offset, 'LineWidth', 1, 'Color', [0 0 0])
       
       title(groups{i});
       
  end
  
  xlim([0 200]);
  ylim([-9.5*10^-6 0.5*10^-6])
  
  x = gca;
  
  x.FontSize = 18;
  xlabel('Latency (ms)');

  x.XTick = [0:25:200];
  x.XTickLabel = [0:1:8];
  
  x.YTick = [-9.5*10^-6:0.5*10^-6:0.5*10^-6];
  
  if subpos == 1;
  x.YTickLabel = [{''} {'10'} {''} {'20'} {''} {'30'} {''} {'40'} {''} {'50'} {''} {'60'} {''} {'70'} {''} {'80'} {''} {'90'} {''} {''}];
  elseif subpos > 1;
  x.YTickLabel = [];
  end
  
  x.XGrid = 'on';
  x.YGrid = 'on';
  x.XMinorTick = 'on';
  
  set(gcf,'renderer','painters')
  
end

%save('amplat.mat', 'amplat');

%Write amplat struct to excel-file
for i = 1:length(fieldnames(amplat))
    
    fields = fieldnames(amplat)
    sheet = fields{i}
    
    xlswrite('amplat.xlsx', amplat.(fields{i}), sheet, 'a1');
  
end