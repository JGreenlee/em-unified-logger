package edu.berkeley.eecs.emission.cordova.unifiedlogger;

import de.appplant.cordova.plugin.localnotification.TriggerReceiver;
import de.appplant.cordova.plugin.notification.Manager;
import de.appplant.cordova.plugin.notification.Options;
import de.appplant.cordova.plugin.notification.Request;
import edu.berkeley.eecs.emission.MainActivity;
import edu.berkeley.eecs.emission.R;

import android.annotation.TargetApi;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;


import java.util.List;


public class NotificationHelper {
	private static String TAG = "NotificationHelper";
	private static String DEFAULT_CHANNEL_ID = "emissionPluginChannel";
	private static String DEFAULT_CHANNEL_DESCRIPTION = "common channel used by all e-mission native plugins";
	public static final String DISPLAY_RESOLUTION_ACTION = "DISPLAY_RESOLUTION";
	public static final String RESOLUTION_PENDING_INTENT_KEY = "rpIntentKey";

	public static void createNotification(Context context, int id, String title, String message) {
		NotificationManager nMgr =
				(NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);

		Notification.Builder builder = getNotificationBuilderForApp(context, title, message);
		/*
		 * This is a bit of magic voodoo. The tutorial on launching the activity actually uses a stackbuilder
		 * to create a fake stack for the new activity. However, it looks like the stackbuilder
		 * is only available in more recent versions of the API. So I use the version for a special activity PendingIntent
		 * (since our app currently has only one activity) which resolves that issue.
		 * This also appears to work, at least in the emulator.
		 * 
		 * TODO: Decide what level API we want to support, and whether we want a more comprehensive activity.
		 */
		Intent activityIntent = new Intent(context, MainActivity.class);
		activityIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
		
		PendingIntent activityPendingIntent = PendingIntent.getActivity(context, 0,
				activityIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
		builder.setContentIntent(activityPendingIntent);		
		
		Log.d(context, TAG, "Generating notify with id " + id + " and message " + message);
		nMgr.notify(id, builder.build());
	}

	public static void createNotification(Context context, int id, String title, String message, PendingIntent intent) {
		NotificationManager nMgr =
				(NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);

		Notification.Builder builder = getNotificationBuilderForApp(context, title , message);
		builder.setContentIntent(intent);

		Log.d(context, TAG, "Generating notify with id " + id + ", message " + message
				+ " and pending intent " + intent);
		nMgr.notify(id, builder.build());
	}

		/*
	 * Used to show a resolution - e.g. to turn on location services
		 */
	public static void createResolveNotification(Context context, int id, String title, String message, PendingIntent intent) {
		NotificationManager nMgr =
				(NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);

		Notification.Builder builder = getNotificationBuilderForApp(context, title, message);

		Intent activityIntent = new Intent(context, MainActivity.class);
		activityIntent.setAction(DISPLAY_RESOLUTION_ACTION);
		activityIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
		activityIntent.putExtra(NotificationHelper.RESOLUTION_PENDING_INTENT_KEY, intent);

		PendingIntent activityPendingIntent = PendingIntent.getActivity(context, 0,
				activityIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
		builder.setContentIntent(activityPendingIntent);
		// builder.setAutoCancel(true);

		Log.d(context, TAG, "Generating notify with id " + id + ", message " + message
				+ " and pending intent " + intent);
		nMgr.notify(id, builder.build());
	}

	public static void cancelNotification(Context context, int id) {
		NotificationManager nMgr =
				(NotificationManager)context.getSystemService(Context.NOTIFICATION_SERVICE);

		Log.d(context, TAG, "Cancelling notify with id " + id);
		nMgr.cancel(id);
	}

	public static Notification.Builder getNotificationBuilderForApp(Context context,
                                                                  String title, String message) {
		Notification.Builder builder = null;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			createDefaultNotificationChannelIfNeeded(context);
			builder = new Notification.Builder(context, DEFAULT_CHANNEL_ID);
		} else {
			builder = new Notification.Builder(context);
		}
		Bitmap appIcon = BitmapFactory.decodeResource(context.getResources(), R.mipmap.ic_launcher);
		builder.setLargeIcon(appIcon);
		builder.setSmallIcon(R.drawable.ic_visibility_black);
		if (title == null) {
		  title = context.getString(R.string.app_name);
    }
		builder.setContentTitle(title);
		builder.setContentText(message);

		return builder;
	}



	@TargetApi(26)
	private static void createDefaultNotificationChannelIfNeeded(final Context ctxt) {
		// only call on Android O and above
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			final NotificationManager notificationManager = (NotificationManager) ctxt.getSystemService(Context.NOTIFICATION_SERVICE);
			List<NotificationChannel> channels = notificationManager.getNotificationChannels();

			for (int i = 0; i < channels.size(); i++) {
				String id = channels.get(i).getId();
				Log.d(ctxt, TAG, "Checking channel with id = "+id);
				if (DEFAULT_CHANNEL_ID.equals(id)) {
					Log.d(ctxt, TAG, "Default channel found, returning");
					return;
				}
			}

			Log.d(ctxt, TAG, "Default channel not found, creating a new one");
			NotificationChannel dChannel = new NotificationChannel(DEFAULT_CHANNEL_ID,
					DEFAULT_CHANNEL_DESCRIPTION, NotificationManager.IMPORTANCE_LOW);
			dChannel.enableVibration(true);
			notificationManager.createNotificationChannel(dChannel);
		}
	}

	/*
	 * Schedules a local notification in a way that is compatible with the local notification plugin
	 * so that we can get a callback in javascript.
	 * The notifyConfig has the basic information required for scheduling such as the title,
	 * the message, the time to schedule, etc. Some of these fields are required, so we will them
	 * in with defaults if they are not present.
	 * Fixed earlier in:
	 * https://github.com/e-mission/e-mission-transition-notify/commit/ec75e28fcc649c54eed65bb8d7e6dc7374336a87
   *
   * Example of expected value
	 * e.g. https://github.com/katzer/cordova-plugin-local-notifications/blob/caff55ec758fdf298029ae98aff7f6a8a097feac/src/android/notification/Options.java#L517
	 *
	 * We pass in the data separately from the config to support the use case of a standard config
	 * with configurable data.
	 */

	public static void schedulePluginCompatibleNotification(Context ctxt,
                                                   JSONObject currNotifyConfig,
                                                   JSONObject newData) {
	  try {
      fillWithDefaults(ctxt, currNotifyConfig, "data", new JSONObject());
      JSONObject defaultTrigger = new JSONObject();
      defaultTrigger.put("type", "calendar");
      fillWithDefaults(ctxt, currNotifyConfig, "trigger", defaultTrigger);
      JSONObject defaultProgressBar = new JSONObject();
      defaultProgressBar.put("enabled", false);
      fillWithDefaults(ctxt, currNotifyConfig, "progressBar", defaultProgressBar);
      JSONObject currData = currNotifyConfig.optJSONObject("data");
      if (newData != null) {
        mergeObjects(currData, newData);
      }
      Manager.getInstance(ctxt).schedule(new Request(new Options(currNotifyConfig)), TriggerReceiver.class);
    } catch (JSONException e) {
      Log.e(ctxt, TAG, e.getMessage());
      Log.e(ctxt, TAG, e.toString());
    }
  }

  private static void mergeObjects(JSONObject existing, JSONObject autogen) throws JSONException {
    /*
      There is now a simpler implementation using toMap() or entrySet()
      https://stackoverflow.com/a/64340427/4040267
      But alas, it looks like the android version does not support these new functions yet
      Sticking to our hard-coded solution
     */
    JSONArray toBeCopiedKeys = autogen.names();
    for(int j = 0; j < toBeCopiedKeys.length(); j++) {
      String currKey = toBeCopiedKeys.getString(j);
      existing.put(currKey, autogen.get(currKey));
    }

  }


  private static void fillWithDefaults(Context ctxt, JSONObject notifyConfig, String field, JSONObject defaultValue) throws JSONException {
	  JSONObject currField = notifyConfig.optJSONObject(field);
	  if (currField == null) {
	    Log.d(ctxt, TAG, "Did not find existing field "+currField+" filling in default");
	    notifyConfig.put(field, defaultValue);
    } else {
      Log.d(ctxt, TAG, "Found existing field "+currField+" retaining existing");
    }
  }
}
