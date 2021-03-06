//
//  TaskModel.m
//  iThunderLiXian
//
//  Created by Martian
//  Editd by Eric
//  Copyright (c) 2012年 CLSX524. All rights reserved.

#import "TaskModel.h"

@implementation TaskModel

@synthesize TaskID;
@synthesize Indeterminate;
@synthesize hash;
@synthesize Cookie;
@synthesize TaskDownloadedSize;
@synthesize TaskLiXianProcess;
@synthesize ButtonEnabled;
@synthesize FatherTaskModel;
@synthesize TaskSizeDescription;
@synthesize CID;
@synthesize YunDelete;
@synthesize LiXianURL;
@synthesize ProgressValue;
@synthesize TaskSize;
@synthesize LeftDownloadTime;
@synthesize LeftTimeButtonHidden;
@synthesize FatherTitle;
@synthesize TaskTypeString;
@synthesize TaskTitle;
@synthesize TaskType;
@synthesize StartAllDownloadNow;
@synthesize download_operation;
@synthesize ButtonTitle;


-(void)dealloc {
    self.TaskID = nil;
    self.TaskType = nil;
    self.TaskLiXianProcess = nil;
    self.TaskSizeDescription = nil;
    self.TaskTitle = nil;
    self.LeftDownloadTime = nil;
}


-(void)start_download
{
    NSLog(@"开始下载：TaskID：%@ TaskTitle：%@ Cookie: %@", self.TaskID, self.TaskTitle, self.Cookie);
    self.Indeterminate = NO;
    self.ProgressValue = 0;
    self.LeftDownloadTime = @"剩余下载时间:未知";
    self.LeftTimeButtonHidden = YES;
    self.ButtonEnabled = NO;
    self.ButtonTitle = @"准备中...";
    
    [self thread_aria2c];   
}

-(void)thread_aria2c
{
    @autoreleasepool {
        NSUInteger last_download_size = 0;        
        NSString *resourcesPath = [[NSBundle mainBundle] resourcePath];
        NSLog(@"%@",resourcesPath);
        NSString *exePath = [NSString stringWithFormat:@"%@/aria2c",resourcesPath];
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:exePath];
        NSArray *args;        
        
        NSString *save_path = [[NSUserDefaults standardUserDefaults] objectForKey:@UD_SAVE_PATH];
        NSInteger max_thread = [[NSUserDefaults standardUserDefaults] integerForKey:@UD_MAX_THREADS];
        NSInteger max_speed = [[NSUserDefaults standardUserDefaults] integerForKey:@UD_TASK_SPEED_LIMIT];
        if (!save_path || [save_path length] == 0) {
            save_path = @"~/Downloads";
        }
        if (max_thread <= 0 || max_thread > 10) {
            max_thread = 10;
        }
        if (max_speed <0) {
            max_speed = 0;
        }
        save_path = [save_path stringByExpandingTildeInPath];
        NSString *max_thread_str = [NSString stringWithFormat:@"%ld", max_thread];
        NSString *max_speed_str = [NSString stringWithFormat:@"%ldK", max_speed];        
        
        if (!self.FatherTitle) {
            args = [NSArray arrayWithObjects:@"--file-allocation=none",@"-c",@"-s",max_thread_str,@"-x",max_thread_str,@"-d",save_path,@"--out",self.TaskTitle, @"--max-download-limit", max_speed_str,@"--header", self.Cookie, self.LiXianURL, nil];
        } else {
            args = [NSArray arrayWithObjects:@"--file-allocation=none",@"-c",@"-s", max_thread_str,@"-x", max_thread_str, @"-d",save_path,@"--out",[NSString stringWithFormat:@"%@/%@",self.FatherTitle,self.TaskTitle], @"--max-download-limit", max_speed_str, @"--header", self.Cookie, self.LiXianURL, nil];
        }        
        
        [task setArguments:args];
        
        [task setStandardOutput:[NSPipe pipe]];
        [task setStandardInput:[NSPipe pipe]];
        [task launch];
        
        char temp[1024];
        char down[64], total[64], percentage[64], speed[64], lefttime[64];        
        
        while (1) {
            sleep(1);
            NSData *data = [[[task standardOutput] fileHandleForReading] availableData];
            NSString *errs=[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            NSLog(@"%@",errs);
            
            if ([errs rangeOfString:@"error occurred."].location != NSNotFound) {
                break;
            }
            if ([errs rangeOfString:@"Exception caught"].location != NSNotFound) {
                continue;
            }
            if ([errs rangeOfString:@"Download Progress Summary"].location != NSNotFound) {
                continue;
            }
            
            if ([errs length] > 100) {
                continue;
            }
            
            // 分析进度
            //[#1 SIZE:9.8MiB/27.5MiB(35%) CN:1 SPD:1.1MiBs ETA:15s]
            //[#1 SIZE:0B/0B CN:1 SPD:0Bs]
            
            
            errs = [errs stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            errs = [errs stringByReplacingOccurrencesOfString:@"/" withString:@" "];
            errs = [errs stringByReplacingOccurrencesOfString:@"(" withString:@" "];
            errs = [errs stringByReplacingOccurrencesOfString:@")" withString:@""];
            
            memset(temp,0,1024*sizeof(char));
            strcpy(temp,[errs cStringUsingEncoding:NSASCIIStringEncoding]);
            sscanf(temp,"%*s SIZE:%s %s %s %*s SPD:%s ETA:%s]", down, total, percentage, speed, lefttime);
            
            self.ButtonEnabled = YES;
            
            self.ButtonTitle = [NSString stringWithFormat:@"%s",speed];
            
            self.ProgressValue = [[[NSString stringWithFormat:@"%s",percentage] stringByReplacingOccurrencesOfString:@"%" withString:@""] integerValue];
            
            self.LeftDownloadTime = [[NSString stringWithFormat:@"剩余下载时间:%s",lefttime] stringByReplacingOccurrencesOfString:@"]" withString:@""];
            self.LeftTimeButtonHidden = NO;
            
            if ([errs rangeOfString:@"%"].location == NSNotFound) {
                self.ButtonTitle = @"0Bs";

            } else {                
                if (self.FatherTaskModel) {
                    //处理BT主任务的进度
                    TaskModel *father_task = self.FatherTaskModel;
                    father_task.Indeterminate = NO;
                    if (father_task.TaskDownloadedSize >= last_download_size)
                        father_task.TaskDownloadedSize -= last_download_size;
                    last_download_size = self.ProgressValue / 100.00 * self.TaskSize;
                    father_task.TaskDownloadedSize += last_download_size;
                    father_task.ProgressValue = father_task.TaskDownloadedSize / (float)father_task.TaskSize * 100;
                    father_task.ButtonTitle = @"正在下载中";
                    father_task.LeftTimeButtonHidden = YES;
                }
            }
            if (![task isRunning]) {
                break;
            }
            if (NeedToStopNow) {
                [task terminate];
                self.ButtonEnabled = NO;
                self.ButtonTitle = @"暂停中...";
                break;
            }
            if (NeedToRestartNow) {
                self.ButtonTitle = @"结束/删除中...";
                [task terminate];
                self.ButtonEnabled = NO;
                break;
            }
        }
        while ([task isRunning]) {
            //DO NOTHING
            //等待程序彻底结束
        }
        
        //错误代码说明
        /*
         
         EXIT STATUS
         Because aria2 can handle multiple downloads at once, it encounters lots
         of errors in a session. aria2 returns the following exit status based
         on the last error encountered.
         
         0
         If all downloads were successful.
         
         1
         If an unknown error occurred.
         
         2
         If time out occurred.
         
         3
         If a resource was not found.
         
         4
         If aria2 saw the specfied number of "resource not found" error. See
         --max-file-not-found option).
         5
         If a download aborted because download speed was too slow. See
         --lowest-speed-limit option)
         
         6
         If network problem occurred.
         
         7
         If there were unfinished downloads. This error is only reported if
         all finished downloads were successful and there were unfinished
         downloads in a queue when aria2 exited by pressing Ctrl-C by an
         user or sending TERM or INT signal.
         
         8
         If remote server did not support resume when resume was required to
         complete download.
         
         9
         If there was not enough disk space available.
         
         10
         If piece length was different from one in .aria2 control file. See
         --allow-piece-length-change option.
         
         11
         If aria2 was downloading same file at that moment.
         
         12
         If aria2 was downloading same info hash torrent at that moment.
         
         13
         If file already existed. See --allow-overwrite option.
         
         14
         If renaming file failed. See --auto-file-renaming option.
         
         15
         If aria2 could not open existing file.
         
         16
         If aria2 could not create new file or truncate existing file.
         
         17
         If file I/O error occurred.
         
         18
         If aria2 could not create directory.
         
         19
         If name resolution failed.
         
         20
         If aria2 could not parse Metalink document.
         
         21
         If FTP command failed.
         
         22
         If HTTP response header was bad or unexpected.
         
         23
         If too many redirections occurred.
         
         24
         If HTTP authorization failed.
         
         25
         If aria2 could not parse bencoded file(usually .torrent file).
         
         26
         If .torrent file was corrupted or missing information that aria2
         needed.
         
         27
         If Magnet URI was bad.
         
         28
         If bad/unrecognized option was given or unexpected option argument
         was given.
         
         29
         If the remote server was unable to handle the request due to a
         temporary overloading or maintenance.
         
         30
         If aria2 could not parse JSON-RPC request.
         
         Note
         An error occurred in a finished download will not be reported as
         exit status.
         
         
         
         
         */
        
        
        switch ([task terminationStatus]) {
                
            case 0:
            {
                //下载完成
                if (self.FatherTaskModel) {
                    //处理BT主任务的进度
                    TaskModel *father_task = self.FatherTaskModel;
                    father_task.Indeterminate = NO;
                    if (father_task.TaskDownloadedSize >= last_download_size)
                        father_task.TaskDownloadedSize -= last_download_size;
                    last_download_size = self.TaskSize;
                    father_task.TaskDownloadedSize += last_download_size;
                    father_task.ProgressValue = father_task.TaskDownloadedSize / (float)father_task.TaskSize * 100;
                    if (father_task.ProgressValue == 100) {
                        father_task.ButtonTitle = @"完成下载";
                    }
                }
                
                self.ButtonEnabled = YES;
                self.LeftTimeButtonHidden = YES;
                self.ButtonTitle = @"完成下载";
                self.ProgressValue = 100;
                if (self.FatherTaskModel) {
                    self.FatherTaskModel.LeftTimeButtonHidden = YES;
                    self.FatherTaskModel.ButtonTitle = @"完成下载";
                }
                
                NSString *request_url = @"http://127.0.0.1:9999/task_delete";
                NSString *request_data;
                NSString *requestResult;

                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                if ([defaults boolForKey:@UD_NOTIFICATION]) {
                    NSUserNotification *unoti = [[NSUserNotification alloc] init];
                    [unoti setTitle:@"iThunderLX - 下载完成"];
                    [unoti setInformativeText:self.TaskTitle];
                    [unoti setHasActionButton:NO];
                    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:unoti];
                }            
                
                if ([defaults integerForKey:@UD_DOWNLOAD_AND_DELETE] == 1) {
                    if (!self.FatherTitle)
                    {
                        request_data = [NSString stringWithFormat:@"hash=%@&tid=%@", self.hash, self.TaskID];
                    } else if (self.FatherTitle && self.FatherTaskModel.ProgressValue == 100) {
                        request_data = [NSString stringWithFormat:@"hash=%@&tid=%@", self.hash, self.FatherTaskModel.TaskID];
                    }                 
                    requestResult = [RequestSender postRequest:request_url withBody:request_data];
                    self.ButtonTitle = @"完成下载";
                    self.TaskLiXianProcess = @"已从云端删除该任务";
                    if (self.FatherTitle) {
                        self.FatherTaskModel.ButtonTitle = @"完成下载";
                        self.FatherTaskModel.TaskLiXianProcess = @"已从云端删除该任务";
                    }  
                }
            }
                break;
                
            case 7:
            {
                //结束/删除
                self.ButtonEnabled = YES;
                self.LeftTimeButtonHidden = YES;
                if (self.FatherTaskModel) {
                    self.FatherTaskModel.LeftTimeButtonHidden = YES;
                    self.FatherTaskModel.indeterminate = YES;
                }
                
                if (NeedToRestartNow) {
                    self.ButtonTitle = @"开始本地下载";
                    self.ProgressValue = 0;
                    NeedToRestartNow = NO;
                    if (self.FatherTaskModel) {
                        self.FatherTaskModel.ButtonTitle = @"开始本地下载";
                    }
                    [self thread_delete_files];
                }
                if (NeedToStopNow)
                {
                    //暂停下载
                    self.ButtonTitle = @"继续下载";
                    NeedToStopNow = NO;
                    if (self.FatherTaskModel) {
                        self.FatherTaskModel.ButtonTitle = @"继续下载";
                    }
                }
            }
                break;
                
            default:
                break;
        }
    }
}

-(void)thread_delete_files
{
    NSFileManager *fileMngr = [NSFileManager defaultManager];
    NSString *file_path = [[NSUserDefaults standardUserDefaults] objectForKey:@UD_SAVE_PATH];
    file_path = [file_path stringByExpandingTildeInPath];
    
    NSString *file_path_orig = file_path;
    NSString *file_path_father = file_path;
    NSArray *listOfFiles;
    if (!self.FatherTitle) {
        file_path_orig = [NSString stringWithFormat:@"%@/%@",file_path, self.TaskTitle];
    }
    else {
        file_path_orig = [NSString stringWithFormat:@"%@/%@/%@",file_path, self.FatherTitle, self.TaskTitle];
        file_path_father = [NSString stringWithFormat:@"%@/%@",file_path, self.FatherTitle];
        listOfFiles = [fileMngr contentsOfDirectoryAtPath:file_path_father error:nil];
    }
    
    NSString *file_path_aria2 =[file_path_orig stringByAppendingPathExtension:@"aria2"];
    
    if([fileMngr fileExistsAtPath:file_path_orig] && [fileMngr fileExistsAtPath:file_path_aria2])
    {
        [fileMngr removeItemAtPath:file_path_orig error:nil];
        [fileMngr removeItemAtPath:file_path_aria2 error:nil];
        if (self.FatherTitle) {
            NSArray *btlist = [NSArray arrayWithObjects:self.TaskTitle, [self.TaskTitle stringByAppendingPathExtension:@"aria2"], nil];
            if ([btlist isEqualToArray:listOfFiles]) {
                [fileMngr removeItemAtPath:file_path_father error:nil];
            }
        }
    }
}

@end
