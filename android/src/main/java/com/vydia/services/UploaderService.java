package com.vydia.RNUploader.services;

import android.support.annotation.NonNull;

import com.birbit.android.jobqueue.JobManager;
import com.birbit.android.jobqueue.scheduling.FrameworkJobSchedulerService;
import com.vydia.RNUploader.UploaderModule;

public class UploaderService extends FrameworkJobSchedulerService {
    @NonNull
    @Override
    protected JobManager getJobManager() {
        return UploaderModule.getInstance().getQueue();
    }
}