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
import java.nio.charset.Charset;

import java.util.*;
import java.lang.reflect.Field;

import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONArray;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;
import com.google.gson.annotations.*;

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

    //   ReadableMap parameters = options.getMap("parameters");
    //   ReadableMapKeySetIterator keys = parameters.keySetIterator();

    //   while (keys.hasNextKey()) {
    //     String key = keys.nextKey();
    //     if (parameters.getType(key) != ReadableType.String || parameters.getType(key) != ReadableType.Boolean) {
    //       promise.reject(new IllegalArgumentException("Parameters must be string key/values(string, boolean, number). Value was invalid for '" + key + "'"));
    //       return;
    //     }
    //   }
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
      jobOptions = Utils.convertMapToJson(options);
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

  /*
   * Cancels file upload
   * Accepts upload ID as a first argument, this upload will be cancelled
   * Event "cancelled" will be fired when upload is cancelled.
   */
  @ReactMethod
  public void cancelUpload(String cancelUploadId, final Promise promise) {
    if (cancelUploadId == null) {
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

  public class ProcessJob extends Job {
    public static final int PRIORITY = 1;
    public String options;
    private boolean jobInProgress = false;

    UploadStatusDelegate statusDelegate;

    public ProcessJob(JSONObject options) {
      // This job requires network connectivity,
      // and should be persisted in case the application exits before job is completed.

      // Disabled jobPresistance here
      super(new Params(PRIORITY).requireNetwork().persist());
      this.options = options.toString();
    }

    @Override
    public void onAdded() {
     Log.d(TAG, String.format("ON ADDED %s", options));
    }

    @Override
    public void onRun() throws Throwable {
      // Job logic goes here. In this example, the network call to post to Twitter is done here.
      // All work done here should be synchronous, a job is removed from the queue once 
      // onRun() finishes.
      Log.d(TAG, String.format("ON RUN %s", options));
      jobInProgress = startUploadJob(options);
      if (!jobInProgress) {
        JSONObject optionsObj = new JSONObject(options);
        UploadService.stopUpload(optionsObj.getString("queueId"));
        return;
      }
      while (jobInProgress) {
        Log.d(TAG, String.format("JOB IN PROGRESS %s", options));
        Thread.sleep(1000);
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
        Log.d(TAG, String.format("ON CANCEL %s", options));
        // Job has exceeded retry attempts or shouldReRunOnThrowable() has decided to cancel.
    } 

    private void sendEvent(String eventName, @Nullable WritableMap params) {
      getInstance().getReactApplicationContext().getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit("RNFileUploader-" + eventName, params);
    }

    // Trigger the request
    public boolean startUploadJob(String jobOptions) throws JSONException {
      JSONObject options = new JSONObject(jobOptions);
      Log.d(TAG, String.format("RUNNING JOB %s", options.toString()));

      WritableMap notification = new WritableNativeMap();
      notification.putBoolean("enabled", true);

      if (options.has("notification") && options.getJSONObject("notification").has("enabled")) {
        notification.putBoolean("enabled", options.getJSONObject("notification").getBoolean("enabled"));
      }

      final String customUploadId = options.getString("customUploadId");
      String url = options.getString("url");
      if (!url.startsWith("http://") && !url.startsWith("https://")) {
        Log.e(TAG, String.format("ERROR STARTING JOB %s: unable to upload to URL %s", customUploadId, url));
        WritableMap params = Arguments.createMap();
        params.putString("id", customUploadId);
        sendEvent("error", params);
        return false;
      }
      String filePath = options.has("path") ? options.getString("path") : "";
      String method = options.has("method") ? options.getString("method") : "POST";
      int bodySizeBits = 0;

      try {
        HttpUploadRequest<?> request;
        String requestType = "raw";
        if (options.has("type")) {
          requestType = options.getString("type");
        }

        if (requestType.equals("json")) {
          // Process JSON request here
          request = new HttpJsonRequest(getInstance().getReactApplicationContext(), customUploadId, url)
                  .setMethod(method)
                  .addHeader("Content-Type", "application/json");
        } else {
          if (!new File(filePath).exists()) {
            Log.e(TAG, String.format("ERROR STARTING JOB %s: file does not exist %s", customUploadId, filePath));
            WritableMap params = Arguments.createMap();
            params.putString("id", customUploadId);
            sendEvent("error", params);
            return false;
          }
          bodySizeBits = (int) new File(filePath).length() * 8;
          Log.e(TAG, String.format("%s is size %d", filePath, bodySizeBits));

          if (requestType.equals("raw")) {
            request = new BinaryUploadRequest(getInstance().getReactApplicationContext(), customUploadId, url)
                    .setFileToUpload(filePath);
          } else {
            request = new MultipartUploadRequest(getInstance().getReactApplicationContext(), customUploadId, url)
                    .addFileToUpload(filePath, options.getString("field"));
          }
        }

        if (statusDelegate == null) {
          statusDelegate = new UploadStatusDelegate() {
            @Override
            public void onProgress(Context context, UploadInfo uploadInfo) {
              WritableMap params = Arguments.createMap();
              params.putString("id", uploadInfo.getUploadId());
              params.putInt("progress", uploadInfo.getProgressPercent()); //0-100
              sendEvent("progress", params);
            }

            @Override
            public void onError(Context context, UploadInfo uploadInfo, final ServerResponse serverResponse, Exception exception) {
              WritableMap params = Arguments.createMap();
              params.putString("id", uploadInfo.getUploadId());
              Log.d(TAG, String.format("ERROR IN JOB %s", uploadInfo.getUploadId()), exception);
              if (exception != null)
                params.putString("error", exception.getMessage());
              else
                Log.e(TAG, "onError has no exception, server response is " + serverResponse.getBodyAsString());
              sendEvent("error", params);
              UploadService.stopUpload(uploadInfo.getUploadId());
              jobInProgress = false;
            }

            @Override
            public void onCompleted(Context context, UploadInfo uploadInfo, ServerResponse serverResponse) {
              WritableMap params = Arguments.createMap();
              params.putString("id", uploadInfo.getUploadId());
              params.putInt("responseCode", serverResponse.getHttpCode());
              params.putString("responseBody", serverResponse.getBodyAsString());
              params.putDouble("duration", uploadInfo.getElapsedTime() / 1000.0);
              sendEvent("completed", params);
              jobInProgress = false;
              Log.d(TAG, String.format("COMPLETED JOB %s, duration %d", uploadInfo.getUploadId(), uploadInfo.getElapsedTime()));
            }

            @Override
            public void onCancelled(Context context, UploadInfo uploadInfo) {
              WritableMap params = Arguments.createMap();
              params.putString("id", uploadInfo.getUploadId());
              sendEvent("cancelled", params);
              jobInProgress = false;
              Log.d(TAG, String.format("CANCELLED JOB %s", uploadInfo.getUploadId()));
            }
          };
        }
        request.setMethod(method)
                .setMaxRetries(2)
                .setDelegate(statusDelegate);

        if (notification.getBoolean("enabled")) {
          UploadNotificationConfig config = new UploadNotificationConfig();
          config.getCancelled().message = null;
          config.getCompleted().message = null;
          config.getError().message = null;
          request.setNotificationConfig(config);
        }

        if (options.has("parameters")) {
          if (requestType.equals("json")) {
            request.addParameter("body", options.getString("parameters"));
            bodySizeBits = options.getString("parameters").length() * 8;
          } else {
            ReadableMap parameters = Utils.convertJsonToMap(options.getJSONObject("parameters"));
            ReadableMapKeySetIterator keys = parameters.keySetIterator();
            while (keys.hasNextKey()) {
              String key = keys.nextKey();
              request.addParameter(key, parameters.getString(key));
            }
          }
        }

        if (options.has("headers")) {
          ReadableMap headers = Utils.convertJsonToMap(options.getJSONObject("headers"));
          ReadableMapKeySetIterator keys = headers.keySetIterator();
          while (keys.hasNextKey()) {
            String key = keys.nextKey();
            request.addHeader(key, headers.getString(key));
          }
        }

        // promise.resolve(uploadId);
        String uploadId = request.startUpload();

        // sent initialize event
        WritableMap params = Arguments.createMap();
        params.putString("id", uploadId);
        params.putInt("size", bodySizeBits);
        sendEvent("initialize", params);

        Log.d(TAG, String.format("STARTED JOB %s", uploadId));
      } catch (Exception exc) {
        Log.e(TAG, exc.getMessage(), exc);
        // promise.reject(exc);
        return false;
      }

      return true;
    }
  }


  public static class GsonSerializer implements JobSerializer {
    private static final Charset UTF8 = Charset.forName("UTF-8");

    public byte[] serialize(Object object) throws IOException {
        if (object == null) {
            return null;
        }
        Gson gson = new GsonBuilder().serializeNulls().enableComplexMapKeySerialization().create();
        String json = gson.toJson(object);
        return json.getBytes(UTF8);
    }

    @Override
    public <T extends Job> T deserialize(byte[] bytes) throws IOException, ClassNotFoundException {
        if (bytes == null || bytes.length == 0) {
            return null;
        }
        Gson gson = new GsonBuilder().serializeNulls().enableComplexMapKeySerialization().create();
        ProcessJob job = gson.fromJson(new String(bytes, UTF8), ProcessJob.class);
        // JSONObject jobOptions = new JSONObject(parsedJob.options);
        // T job = new ProcessJob(jobOptions);
        return (T) job;
    }
  }

  private void configureQueue() {
    JobSerializer jobSerializer = new GsonSerializer();
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
