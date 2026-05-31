package com.eopeter.fluttermapboxnavigation.activity;

import android.app.Activity;
import android.content.Intent;

import com.eopeter.fluttermapboxnavigation.models.Waypoint;

import java.io.Serializable;
import java.util.List;

public class NavigationLauncher {
    public static final String KEY_ADD_WAYPOINTS = "com.my.mapbox.broadcast.ADD_WAYPOINTS";
    public static final String KEY_STOP_NAVIGATION = "com.my.mapbox.broadcast.STOP_NAVIGATION";
    public static final String KEY_REROUTE = "com.my.mapbox.broadcast.REROUTE";
    public static final String KEY_UPDATE_HAZARDS = "com.my.mapbox.broadcast.UPDATE_HAZARDS";
    public static void startNavigation(Activity activity, List<Waypoint> wayPoints) {
        Intent navigationIntent = new Intent(activity, NavigationActivity.class);
        navigationIntent.putExtra("waypoints", (Serializable) wayPoints);
        activity.startActivity(navigationIntent);
    }

    public static void addWayPoints(Activity activity, List<Waypoint> wayPoints) {
        // Action-only (implicit) broadcast so the runtime-registered receiver in
        // NavigationActivity matches it. An explicit-component intent is NOT
        // delivered to a registerReceiver() receiver (it has no component name).
        Intent navigationIntent = new Intent();
        navigationIntent.setAction(KEY_ADD_WAYPOINTS);
        navigationIntent.putExtra("isAddingWayPoints", true);
        navigationIntent.putExtra("waypoints", (Serializable) wayPoints);
        activity.sendBroadcast(navigationIntent);
    }

    public static void stopNavigation(Activity activity) {
        Intent stopIntent = new Intent();
        stopIntent.setAction(KEY_STOP_NAVIGATION);
        activity.sendBroadcast(stopIntent);
    }

    public static void reroute(Activity activity, List<Waypoint> wayPoints) {
        // Action-only broadcast (see addWayPoints) — explicit-component intents
        // are dropped by runtime-registered receivers.
        Intent intent = new Intent();
        intent.setAction(KEY_REROUTE);
        intent.putExtra("waypoints", (Serializable) wayPoints);
        activity.sendBroadcast(intent);
    }

    public static void updateHazards(Activity activity, Serializable hazards) {
        Intent intent = new Intent();
        intent.setAction(KEY_UPDATE_HAZARDS);
        intent.putExtra("hazards", hazards);
        activity.sendBroadcast(intent);
    }
}
