package com.vydia.RNUploader;

import android.content.Context;
import android.os.Build;
import android.support.annotation.Nullable;
import android.util.Log;
import android.webkit.MimeTypeMap;

import com.birbit.android.jobqueue.config.Configuration;
import com.birbit.android.jobqueue.log.CustomLogger;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableMapKeySetIterator;
import com.facebook.react.bridge.ReadableType;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import net.gotev.uploadservice.BinaryUploadRequest;
import net.gotev.uploadservice.HttpUploadRequest;
import net.gotev.uploadservice.MultipartUploadRequest;
import net.gotev.uploadservice.HttpJsonRequest;
import net.gotev.uploadservice.ServerResponse;
import net.gotev.uploadservice.UploadInfo;
import net.gotev.uploadservice.UploadNotificationConfig;
import net.gotev.uploadservice.UploadService;
import net.gotev.uploadservice.UploadStatusDelegate;
import net.gotev.uploadservice.okhttp.OkHttpStack;

import java.io.File;
import java.lang.Object;
import java.io.IOException;
import java.lang.ClassNotFoundException;
import java.io.ByteArrayOutputStream;
import java.io.ObjectOutputStream;
import java.io.ObjectOutput;
import java.io.ObjectInputStream;
import java.io.ByteArrayInputStream;
import java.util.UUID;

import java.util.*;
import java.lang.reflect.Field;

import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONArray;

import com.google.gson.Gson;


import com.birbit.android.jobqueue.JobManager;
import com.birbit.android.jobqueue.scheduling.FrameworkJobSchedulerService;
import com.birbit.android.jobqueue.JobManager;
import com.birbit.android.jobqueue.config.Configuration;
import com.birbit.android.jobqueue.log.CustomLogger;
import com.birbit.android.jobqueue.scheduling.GcmJobSchedulerService;
//import com.google.android.gms.common.ConnectionResult;
//import com.google.android.gms.common.GoogleApiAvailability;
import com.birbit.android.jobqueue.persistentQueue.sqlite.SqliteJobQueue.JobSerializer;

import com.birbit.android.jobqueue.CancelReason;
import com.birbit.android.jobqueue.Job;
import com.birbit.android.jobqueue.Params;
import com.birbit.android.jobqueue.RetryConstraint;

import com.vydia.RNUploader.services.UploaderService;
import com.vydia.RNUploader.Utils.Utils;



public class UploaderModule extends ReactContextBaseJavaModule {
  private static final String TAG = "UploaderBridge";
  private static UploaderModule instance;
  private JobManager queue;
  private boolean jobInProgress;
  private Utils utils = new Utils();

  public UploaderModule(ReactApplicationContext reactContext) {
    super(reactContext);
    UploadService.NAMESPACE = reactContext.getApplicationInfo().packageName;
    UploadService.HTTP_STACK = new OkHttpStack();
    queue = getQueue();
    instance = this;
  }

  @Override
  public String getName() {
    return "RNFileUploader";
  }

  /*
  Sends an event to the JS module.
   */
  private void sendEvent(String eventName, @Nullable WritableMap params) {
    this.getReactApplicationContext().getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RNFileUploader-" + eventName, params);
  }

  /*
  Gets file information for the path specified.  Example valid path is: /storage/extSdCard/DCIM/Camera/20161116_074726.mp4
  Returns an object such as: {extension: "mp4", size: "3804316", exists: true, mimeType: "video/mp4", name: "20161116_074726.mp4"}
   */
  @ReactMethod
  public void getFileInfo(String path, final Promise promise) {
    try {
      WritableMap params = Arguments.createMap();
      File fileInfo = new File(path);
      params.putString("name", fileInfo.getName());
      if (!fileInfo.exists() || !fileInfo.isFile())
      {
        params.putBoolean("exists", false);
      }
      else
      {
        params.putBoolean("exists", true);
        params.putString("size",Long.toString(fileInfo.length())); //use string form of long because there is no putLong and converting to int results in a max size of 17.2 gb, which could happen.  Javascript will need to convert it to a number
        String extension = MimeTypeMap.getFileExtensionFromUrl(path);
        params.putString("extension",extension);
        String mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.toLowerCase());
        params.putString("mimeType", mimeType);
      }

      promise.resolve(params);
    } catch (Exception exc) {
      Log.e(TAG, exc.getMessage(), exc);
      promise.reject(exc);
    }
  }

  public class ProcessJob extends Job {
    private long localId;
    public static final int PRIORITY = 1;
    public transient JSONObject options;
    public ProcessJob(JSONObject options) {
      // This job requires network connectivity,
      // and should be persisted in case the application exits before job is completed.

      // Disabled jobPresistance here
      super(new Params(PRIORITY).requireNetwork().persist());
      // super(new Params(PRIORITY).requireNetwork());
      localId = -System.currentTimeMillis();
      this.options = options;
    }
    @Override
    public void onAdded() {
//      Log.d(TAG, String.format("ADDED JOB %s : %s", options.get("url"), options.getJSONObject("parameters").getString("id")));
      // Job has been saved to disk.
      // This is a good place to dispatch a UI event to indicate the job will eventually run.
      // In this example, it would be good to update the UI with the newly posted tweet.
    }
    @Override
    public void onRun() throws Throwable {
      // Job logic goes here. In this example, the network call to post to Twitter is done here.
      // All work done here should be synchronous, a job is removed from the queue once 
      // onRun() finishes.
      // Log.d(TAG, String.format("STARTED JOB %s : %s", options.get("url"), options.getJSONObject("parameters").getString("id")));
      Log.d(TAG, String.format("SAVED JOB %s", options));
      startUploadJob(options);
      jobInProgress = true;
      while (jobInProgress) {
        Log.d(TAG, String.format("JOB IN PROGRESS %s", options));
      }
    }
    @Override
    protected RetryConstraint shouldReRunOnThrowable(Throwable throwable, int runCount,
            int maxRunCount) {
        // An error occurred in onRun.
        // Return value determines whether this job should retry or cancel. You can further
        // specify a backoff strategy or change the job's priority. You can also apply the
        // delay to the whole group to preserve jobs' running order.
        return RetryConstraint.createExponentialBackoff(runCount, 1000);
    }
    @Override
    protected void onCancel(@CancelReason int cancelReason, @Nullable Throwable throwable) {
        // Job has exceeded retry attempts or shouldReRunOnThrowable() has decided to cancel.
    } 

    @Override
    public String toString() {
      StringBuilder result = new StringBuilder();
      String newLine = System.getProperty("line.separator");

      result.append( this.getClass().getName() );
      result.append( " Object {" );
      result.append(newLine);

      //determine fields declared in this class only (no fields of superclass)
      Field[] fields = this.getClass().getDeclaredFields();

      //print field names paired with their values
      for ( Field field : fields  ) {
        result.append("  ");
        try {
          result.append( field.getName() );
          result.append(": ");
          //requires access to private field:
          result.append( field.get(this) );
        } catch ( IllegalAccessException ex ) {
          System.out.println(ex);
        }
        result.append(newLine);
      }
      result.append("}");

      return result.toString();
    }
  }

  /*
   * Starts a file upload.
   * Returns a promise with the string ID of the upload.
   *
   * Type check parameters and resolve or reject the promise 
   * Add options to the background queue
   */
  @ReactMethod
  public void startUpload(ReadableMap options, final Promise promise) {
    for (String key : new String[]{"url"}) {
      if (!options.hasKey(key)) {
        promise.reject(new IllegalArgumentException("Missing '" + key + "' field."));
        return;
      }
      if (options.getType(key) != ReadableType.String) {
        promise.reject(new IllegalArgumentException(key + " must be a string."));
        return;
      }
    }

    if (options.hasKey("headers") && options.getType("headers") != ReadableType.Map) {
      promise.reject(new IllegalArgumentException("headers must be a hash."));
      return;
    }

    if (options.hasKey("notification") && options.getType("notification") != ReadableType.Map) {
      promise.reject(new IllegalArgumentException("notification must be a hash."));
      return;
    }

    // Supported types are raw, json, multipart
    String requestType = "raw";
    if (options.hasKey("type")) {
      requestType = options.getString("type");
      if (requestType == null) {
        promise.reject(new IllegalArgumentException("type must be string."));
        return;
      }

      if (!requestType.equals("raw") && !requestType.equals("multipart") && !requestType.equals("json")) {
        promise.reject(new IllegalArgumentException("type should be string: raw, multipart or json."));
        return;
      }

      // If type if multipart, it should have field
      if (requestType.equals("multipart")) {
        if (!options.hasKey("field")) {
          promise.reject(new IllegalArgumentException("field is required field for multipart type."));
          return;
        }
        if (options.getType("field") != ReadableType.String) {
          promise.reject(new IllegalArgumentException("field must be string."));
          return;
        }
      }
    }

    // Validate parameters
    if (options.hasKey("parameters")) {
      requestType = options.getString("type");
      if (requestType.equals("raw")) {
        promise.reject(new IllegalArgumentException("Parameters supported only in multipart type"));
        return;
      }

      ReadableMap parameters = options.getMap("parameters");
      ReadableMapKeySetIterator keys = parameters.keySetIterator();
      
      while (keys.hasNextKey()) {
        String key = keys.nextKey();
        if (parameters.getType(key) != ReadableType.String) {
          promise.reject(new IllegalArgumentException("Parameters must be string key/values. Value was invalid for '" + key + "'"));
          return;
        }
      }
    }

    // Validate headers
    if (options.hasKey("headers")) {
      ReadableMap headers = options.getMap("headers");
      ReadableMapKeySetIterator keys = headers.keySetIterator();
      while (keys.hasNextKey()) {
        String key = keys.nextKey();
        if (headers.getType(key) != ReadableType.String) {
          promise.reject(new IllegalArgumentException("Headers must be string key/values.  Value was invalid for '" + key + "'"));
          return;
        }
      }
    }

    // Fetch the uploadId

    String uploadId = "";
    JSONObject jobOptions;
    try {
      jobOptions = utils.convertMapToJson(options);
      // CustonUploadID is not provided, generate one
      if (!options.hasKey("customUploadId") || (options.hasKey("customUploadId") && options.getType("customUploadId") !=  ReadableType.String)) {
          UUID uuid = UUID.randomUUID();
          uploadId = uuid.toString();
          jobOptions.put("customUploadId", uploadId);
      } else {
          uploadId = options.getString("customUploadId");
      }
      // Add request to Queue
      queue.addJobInBackground(new ProcessJob(jobOptions));

      // Resolve uploadId
      promise.resolve(uploadId);
    } catch(Exception error) {
      Log.e(TAG, error.getMessage(), error);
      promise.reject(error);
      return;
    }
  }

  // Trigger the request
  public void startUploadJob(JSONObject options) throws JSONException {

    WritableMap notification = new WritableNativeMap();
    notification.putBoolean("enabled", true);

    if (options.has("notification")) {
      notification.merge(utils.convertJsonToMap(options.getJSONObject("notification")));
    }

    String url = options.getString("url");
    String filePath = options.has("path") ? options.getString("path") : "";
    String method = options.has("method") && options.get("method") == ReadableType.String ? options.getString("method") : "POST";

    final String customUploadId = options.has("customUploadId") && options.get("method") == ReadableType.String ? options.getString("customUploadId") : null;

    try {
      UploadStatusDelegate statusDelegate = new UploadStatusDelegate() {
        @Override
        public void onProgress(Context context, UploadInfo uploadInfo) {
          WritableMap params = Arguments.createMap();
          params.putString("id", customUploadId != null ? customUploadId : uploadInfo.getUploadId());
          params.putInt("progress", uploadInfo.getProgressPercent()); //0-100
          sendEvent("progress", params);
        }

        @Override
        public void onError(Context context, UploadInfo uploadInfo, Exception exception) {
          WritableMap params = Arguments.createMap();
          params.putString("id", customUploadId != null ? customUploadId : uploadInfo.getUploadId());
          params.putString("error", exception.getMessage());
          sendEvent("error", params);
        }

        @Override
        public void onCompleted(Context context, UploadInfo uploadInfo, ServerResponse serverResponse) {
          WritableMap params = Arguments.createMap();
          params.putString("id", customUploadId != null ? customUploadId : uploadInfo.getUploadId());
          params.putInt("responseCode", serverResponse.getHttpCode());
          params.putString("responseBody", serverResponse.getBodyAsString());
          sendEvent("completed", params);
          jobInProgress = false;
        }

        @Override
        public void onCancelled(Context context, UploadInfo uploadInfo) {
          WritableMap params = Arguments.createMap();
          params.putString("id", customUploadId != null ? customUploadId : uploadInfo.getUploadId());
          sendEvent("cancelled", params);
          jobInProgress = false;
        }
      };

      HttpUploadRequest<?> request;
      String requestType = "raw";
      if (options.has("type")) {
        requestType = options.getString("type");
      }

      if (requestType.equals("raw")) {
        request = new BinaryUploadRequest(this.getReactApplicationContext(), customUploadId, url)
                .setFileToUpload(filePath);
      } else if (requestType.equals("json")) {
        // Process JSON request here
        request = new HttpJsonRequest(this.getReactApplicationContext(), customUploadId, url)
                .setMethod(method)
                .addHeader("Content-Type", "application/json");
      } else {
        request = new MultipartUploadRequest(this.getReactApplicationContext(), customUploadId, url)
                .addFileToUpload(filePath, options.getString("field"));
      }


      request.setMethod(method)
        .setMaxRetries(2)
        .setDelegate(statusDelegate);

      if (notification.getBoolean("enabled")) {
        request.setNotificationConfig(new UploadNotificationConfig());
      }

      if (options.has("parameters")) {

        ReadableMap parameters = utils.convertJsonToMap(options.getJSONObject("parameters"));
        ReadableMapKeySetIterator keys = parameters.keySetIterator();

        while (keys.hasNextKey()) {
          String key = keys.nextKey();
          request.addParameter(key, parameters.getString(key));
        }
      }

      if (options.has("headers")) {
        ReadableMap headers = utils.convertJsonToMap(options.getJSONObject("headers"));
        ReadableMapKeySetIterator keys = headers.keySetIterator();
        while (keys.hasNextKey()) {
          String key = keys.nextKey();
          request.addHeader(key, headers.getString(key));
        }
      }
      // String uploadId = request.startUpload();
      // promise.resolve(uploadId);
      String uploadId = request.startUpload();
      Log.d(TAG, String.format("FINISHED JOB %s", uploadId));
    } catch (Exception exc) {
      Log.e(TAG, exc.getMessage(), exc);
      // promise.reject(exc);
    }
  }

  /*
   * Cancels file upload
   * Accepts upload ID as a first argument, this upload will be cancelled
   * Event "cancelled" will be fired when upload is cancelled.
   */
  @ReactMethod
  public void cancelUpload(String cancelUploadId, final Promise promise) {
    if (!(cancelUploadId instanceof String)) {
      promise.reject(new IllegalArgumentException("Upload ID must be a string"));
      return;
    }
    try {
      UploadService.stopUpload(cancelUploadId);
      promise.resolve(true);
    } catch (Exception exc) {
      Log.e(TAG, exc.getMessage(), exc);
      promise.reject(exc);
    }
  }

  // Docs
  //http://yigit.github.io/android-priority-jobqueue/javadoc/com/birbit/android/jobqueue/persistentQueue/sqlite/SqliteJobQueue.JobSerializer.html
  // https://github.com/yigit/android-priority-jobqueue/blob/58fc9dfc63f1358b32b26a262a81e2b98e6441ae/jobqueue/src/main/java/com/birbit/android/jobqueue/persistentQueue/sqlite/SqliteJobQueue.java

  // Default Serializer
  public static class CustomSerializer implements JobSerializer {

    public byte[] serialize(Object object) throws IOException {
        if (object == null) {
            return null;
        }

        Field[] fields = object.getClass().getDeclaredFields();
        for ( Field field : fields  ) {
          if (field.getName().toString() == "options") {
            try {
                Object options = field.get(object);
                Log.d(TAG, String.format("SERIALIZE JOB OPTIONS %s:%s", field.getName(), options));
                // field.set(object, options.toString());
            } catch ( IllegalAccessException ex ) {
                Log.e(TAG, ex.getMessage(), ex);
            }
          }
        }

        ByteArrayOutputStream bos = null;
        Log.d(TAG, String.format("SERIALIZE JOB %s", object.toString()));
        try {
            bos = new ByteArrayOutputStream();
            ObjectOutput out = new ObjectOutputStream(bos);
            out.writeObject(object.toString());
            // Get the bytes of the serialized object
            return bos.toByteArray();
        } catch (Exception exc) {
          Log.e(TAG, String.format("SERIALIZE JOB ERROR %s", exc.getMessage()), exc);
          throw exc;
        } finally {
            if (bos != null) {
                bos.close();
            }
        }
    }

    @Override
    public <T extends Job> T deserialize(byte[] bytes) throws IOException, ClassNotFoundException {
        if (bytes == null || bytes.length == 0) {
            return null;
        }
        ObjectInputStream in = null;
        try {
            in = new ObjectInputStream(new ByteArrayInputStream(bytes));
            //noinspection unchecked
            return (T) in.readObject();
        } finally {
            if (in != null) {
                in.close();
            }
        }
    }
  }

  private void configureQueue() {
    JobSerializer jobSerializer = new CustomSerializer();
    Configuration.Builder builder = new Configuration.Builder(this.getReactApplicationContext())
            .customLogger(new CustomLogger() {
              private static final String TAG = "Queue";
              @Override
              public boolean isDebugEnabled() {
                return true;
              }

              @Override
              public void d(String text, Object... args) {
                Log.d(TAG, String.format(text, args));
              }

              @Override
              public void e(Throwable t, String text, Object... args) {
                Log.e(TAG, String.format(text, args), t);
              }

              @Override
              public void e(String text, Object... args) {
                Log.e(TAG, String.format(text, args));
              }

              @Override
              public void v(String text, Object... args) {

              }
            })
            .jobSerializer(jobSerializer)
            .minConsumerCount(1)//always keep at least one consumer alive
            .maxConsumerCount(1)//up to 1 consumers at a time
            .loadFactor(1)//1 jobs per consumer
            .consumerKeepAlive(60);//wait 60 minute

    // Background Service
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
        builder.scheduler(FrameworkJobSchedulerService.createSchedulerFor(this.getReactApplicationContext(),
                UploaderService.class), true);
    // } else {
    //     int enableGcm = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this);
    //     if (enableGcm == ConnectionResult.SUCCESS) {
    //         builder.scheduler(GcmJobSchedulerService.createSchedulerFor(this,
    //                 MyGcmJobService.class), true);
    //     }
    }
    queue = new JobManager(builder.build());
  }

  public synchronized JobManager getQueue() {
    if (queue == null) {
      configureQueue();
    }
    return queue;
  }

  public static UploaderModule getInstance() {
      return instance;
  }
}
