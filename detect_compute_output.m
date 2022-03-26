clear
format long

%% Set folder location
path='D:\***';
%date=datetime('20211224','Format','yyyyMMdd');
date=datetime('today','Format','yyyyMMdd');
date_formatted=datestr(date,'yyyy-mm-dd');
folder=datestr(date,'yyyymmdd');

%% Check current progress
% Connect to database
db_conn=database('***','root','password');
exp_id_query=['SELECT customize_id FROM experiments WHERE date LIKE ''',date_formatted,'%'''];
exp_id_result=select(db_conn,exp_id_query);
if isempty(exp_id_result)
    exp_id_prev='NULL';
    processed_count=0;
else
    exp_id_prev=char(exp_id_result{end,1});
    count_query=['SELECT count(*) FROM experiment_results WHERE exp_customize_id LIKE ''',date_formatted,'%'''];
    processed_count=select(db_conn,count_query);
    processed_count=processed_count{1,1};
end

%% Main program
new_file=true;
new_session=true;
data_window=zeros(6,2);
while new_file
    % Detect new files
    files=dir(fullfile(path,folder,'*.jpg'));
    current_count=numel(files);
    if current_count==processed_count
        % Double Check before terminating program
        disp('Timer start')
        pause(30)
        files=dir(fullfile(path,folder,'*.jpg'));
        current_count=numel(files);
        if current_count==processed_count
            disp('Timeout')
            new_file=false;
        end
    else
        % Sort files by time
        [~,time_index]=sort([files.datenum]);
        files=files(time_index);
    end
    % Start processing new files
    while current_count>processed_count
        % Get information from filename
        file_location=fullfile(path,folder,files(processed_count+1).name);
        image_url=['https://***/',folder,'/',files(processed_count+1).name];
        filename=files(processed_count+1).name;
        info=strsplit(filename,'_');
        cornea=char(info(1));
        cornea=cornea(2:4);
        cl_name=info(2);
        exp=info(3);
        exp_info=strsplit(char(exp),'-');
        pressure=str2double(exp_info(1));
        trial=str2double(exp_info(2));
        time=extract(info(4),digitsPattern(6));
        local_time=datetime(strcat(folder,time),'InputFormat','yyyyMMddHHmmss');
        date_formatted=datestr(local_time,'yyyy-mm-dd');
        exp_id=strjoin([date_formatted,cl_name,cornea,exp],'_');
        % Convert local time (UTC+8) to Unix time (UTC+0)
        posix_time=posixtime(local_time-hours(8));
        % Image analysis
        try
            [benta,merra]=test2_v8a(file_location,0);
        catch
            benta=0;
            merra=0;
        end
        % Check database whenever program first starts
        if new_session
            % Get last 6 records of benta and merra
            data_query=['SELECT benta, merra FROM experiment_results WHERE exp_customize_id = ''', ...
                exp_id,''' ORDER BY id DESC LIMIT 6'];
            data_db=select(db_conn,data_query);
            data_window(1:height(data_db),:)=data_db{:,:};
            new_session=false;
        end
        % Send experiment information if database has no record
        if ~strcmp(exp_id,exp_id_prev)
            exp_cols={'customize_id' 'date' 'cornea' 'cl_name' 'pressure' 'trial'};
            exp_cell=[exp_id,date_formatted,cornea,cl_name,pressure,trial];
            out_exp=cell2table(exp_cell,'VariableNames',exp_cols);
            sqlwrite(db_conn,'experiments',out_exp)
            exp_id_prev=exp_id;
            % Reset data window
            data_window=zeros(6,2);
        end
        % Compute moving average
        data_window=vertcat([benta,merra],data_window(1:end-1,:));
        benta_mov_avg=mean(nonzeros(data_window(:,1)));
        merra_mov_avg=mean(nonzeros(data_window(:,2)));
        % Output results to database
        result_cols={'exp_customize_id' 'time' 'benta' 'merra' 'benta_mov_avg' 'merra_mov_avg' 'image_url'};
        result_cell={exp_id,posix_time,benta,merra,benta_mov_avg,merra_mov_avg,image_url};
        out_result=cell2table(result_cell,'VariableNames',result_cols);
        % Send experiment results
        try
            sqlwrite(db_conn,'experiment_results',out_result)
        catch
            disp('Failed to write database.')
            processed_count=processed_count-1;
        end
        % Display current progress
        processed_count=processed_count+1;
        disp(['Progress: ',num2str(processed_count),'/',num2str(current_count)])
    end
end
% Close database connection
close(db_conn)