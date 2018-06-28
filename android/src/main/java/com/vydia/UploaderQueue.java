// package com.vydia.RNUploader;

// import com.birbit.android.jobqueue.scheduling.FrameworkJobSchedulerService;
// import com.birbit.android.jobqueue.JobManager;
// import com.birbit.android.jobqueue.config.Configuration;
// import com.birbit.android.jobqueue.log.CustomLogger;
// import com.birbit.android.jobqueue.scheduling.GcmJobSchedulerService;
// import com.google.android.gms.common.ConnectionResult;
// import com.google.android.gms.common.GoogleApiAvailability;
// import com.birbit.android.jobqueue.persistentQueue.sqlite;

//   // Job Queue
// public class Queue extends JobManager {
//   private JobManager queue;

//   @Override
//   public void onCreate() {
//     super.onCreate();
//     getQueue();
//   }

//   private void configureQueue() {
//     Configuration.Builder builder = new Configuration.Builder(this)
//     .customLogger(new CustomLogger() {
//         private static final String TAG = "Queue";
//         @Override
//         public boolean isDebugEnabled() {
//             return true;
//         }

//         @Override
//         public void d(String text, Object... args) {
//             Log.d(TAG, String.format(text, args));
//         }

//         @Override
//         public void e(Throwable t, String text, Object... args) {
//             Log.e(TAG, String.format(text, args), t);
//         }

//         @Override
//         public void e(String text, Object... args) {
//             Log.e(TAG, String.format(text, args));
//         }

//         @Override
//         public void v(String text, Object... args) {

//         }
//     })
//     .minConsumerCount(1)//always keep at least one consumer alive
//     .maxConsumerCount(1)//up to 1 consumers at a time
//     .loadFactor(1)//1 jobs per consumer
//     .consumerKeepAlive(300);//wait 5 minute

//     // Use http://yigit.github.io/android-priority-jobqueue/javadoc/com/birbit/android/jobqueue/config/Configuration.Builder.html#queueFactory(com.birbit.android.jobqueue.QueueFactory)

//     // Use SqliteJobQueue.JobSerializer for job presistance

//     // Service
//     // if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
//     //     builder.scheduler(FrameworkJobSchedulerService.createSchedulerFor(this,
//     //             MyJobService.class), true);
//     // } else {
//     //     int enableGcm = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this);
//     //     if (enableGcm == ConnectionResult.SUCCESS) {
//     //         builder.scheduler(GcmJobSchedulerService.createSchedulerFor(this,
//     //                 MyGcmJobService.class), true);
//     //     }
//     // }
//     queue = new JobManager(builder.build());
//   }

//   public synchronized JobManager getQueue() {
//     if (queue == null) {
//         configureQueue();
//     }
//     return queue;
//   }
// }