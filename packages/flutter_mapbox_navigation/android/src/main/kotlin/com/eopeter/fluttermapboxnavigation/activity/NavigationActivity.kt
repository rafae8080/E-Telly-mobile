package com.eopeter.fluttermapboxnavigation.activity

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.core.content.ContextCompat
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.location.Location
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import com.eopeter.fluttermapboxnavigation.FlutterMapboxNavigationPlugin
import com.eopeter.fluttermapboxnavigation.R
import androidx.appcompat.R as AppCompatR
import com.eopeter.fluttermapboxnavigation.databinding.NavigationActivityBinding
import com.eopeter.fluttermapboxnavigation.models.MapBoxEvents
import com.eopeter.fluttermapboxnavigation.models.MapBoxRouteProgressEvent
import com.eopeter.fluttermapboxnavigation.models.Waypoint
import com.eopeter.fluttermapboxnavigation.models.WaypointSet
import com.eopeter.fluttermapboxnavigation.utilities.CustomInfoPanelEndNavButtonBinder
import com.eopeter.fluttermapboxnavigation.utilities.PluginUtilities
import com.eopeter.fluttermapboxnavigation.utilities.PluginUtilities.Companion.sendEvent
import com.google.gson.Gson
import com.mapbox.api.directions.v5.models.DirectionsRoute
import com.mapbox.api.directions.v5.models.RouteOptions
import com.mapbox.geojson.Point
import com.mapbox.maps.MapView
import com.mapbox.maps.Style
import com.mapbox.maps.plugin.annotation.annotations
import com.mapbox.maps.plugin.annotation.generated.PointAnnotationManager
import com.mapbox.maps.plugin.annotation.generated.PointAnnotationOptions
import com.mapbox.maps.plugin.annotation.generated.createPointAnnotationManager
import com.mapbox.maps.plugin.gestures.OnMapLongClickListener
import com.mapbox.maps.plugin.gestures.gestures
import com.mapbox.navigation.base.extensions.applyDefaultNavigationOptions
import com.mapbox.navigation.base.extensions.applyLanguageAndVoiceUnitOptions
import com.mapbox.navigation.base.options.NavigationOptions
import com.mapbox.navigation.base.route.NavigationRoute
import com.mapbox.navigation.base.route.NavigationRouterCallback
import com.mapbox.navigation.base.route.RouterFailure
import com.mapbox.navigation.base.route.RouterOrigin
import com.mapbox.navigation.base.trip.model.RouteLegProgress
import com.mapbox.navigation.base.trip.model.RouteProgress
import com.mapbox.navigation.core.arrival.ArrivalObserver
import com.mapbox.navigation.core.directions.session.RoutesObserver
import com.mapbox.navigation.core.lifecycle.MapboxNavigationApp
import com.mapbox.navigation.core.trip.session.BannerInstructionsObserver
import com.mapbox.navigation.core.trip.session.LocationMatcherResult
import com.mapbox.navigation.core.trip.session.LocationObserver
import com.mapbox.navigation.core.trip.session.OffRouteObserver
import com.mapbox.navigation.core.trip.session.RouteProgressObserver
import com.mapbox.navigation.core.trip.session.VoiceInstructionsObserver
import com.mapbox.navigation.dropin.map.MapViewObserver
import com.mapbox.navigation.dropin.navigationview.NavigationViewListener
import com.mapbox.navigation.utils.internal.ifNonNull

class NavigationActivity : AppCompatActivity() {
    private var finishBroadcastReceiver: BroadcastReceiver? = null
    private var addWayPointsBroadcastReceiver: BroadcastReceiver? = null
    private var rerouteBroadcastReceiver: BroadcastReceiver? = null
    private var updateHazardsBroadcastReceiver: BroadcastReceiver? = null
    private var hazardAnnotationManager: PointAnnotationManager? = null
    private var hazardMapView: MapView? = null
    private var pendingHazards: List<HashMap<*, *>> = listOf()
    private var points: MutableList<Waypoint> = mutableListOf()

    companion object {
        // Live reference to the running navigation activity so the plugin can drive
        // it directly (reroute / hazard markers) without relying on broadcast
        // delivery, which proved unreliable on-device.
        @JvmStatic
        var instance: NavigationActivity? = null
            private set
    }

    /** Replaces the active route live with one built from [stops]. */
    fun applyReroute(stops: List<Waypoint>) {
        Log.d("EvacHazard", "applyReroute: ${stops.size} waypoints")
        if (stops.isEmpty()) return
        runOnUiThread {
            val set = WaypointSet()
            stops.forEach { set.add(it) }
            requestRoutes(set)
        }
    }

    /** Replaces the drawn hazard markers with [hazards] ({lat,lng,severity} maps). */
    fun applyHazards(hazards: List<HashMap<*, *>>) {
        Log.d("EvacHazard", "applyHazards: ${hazards.size} hazards")
        runOnUiThread {
            pendingHazards = hazards
            renderHazards()
        }
    }
    private var waypointSet: WaypointSet = WaypointSet()
    private var canResetRoute: Boolean = false
    private var accessToken: String? = null
    private var lastLocation: Location? = null
    private var isNavigationInProgress = false

    private val navigationStateListener = object : NavigationViewListener() {
        override fun onFreeDrive() {

        }

        override fun onDestinationPreview() {

        }

        override fun onRoutePreview() {

        }

        override fun onActiveNavigation() {
            isNavigationInProgress = true
        }

        override fun onArrival() {

        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        setTheme(AppCompatR.style.Theme_AppCompat_NoActionBar)
        binding = NavigationActivityBinding.inflate(layoutInflater)
        setContentView(binding.root)
        binding.navigationView.addListener(navigationStateListener)
        accessToken =
            PluginUtilities.getResourceFromContext(this.applicationContext, "mapbox_access_token")

        val navigationOptions = NavigationOptions.Builder(this.applicationContext)
            .accessToken(accessToken)
            .build()

        MapboxNavigationApp
            .setup(navigationOptions)
            .attach(this)

        if (FlutterMapboxNavigationPlugin.longPressDestinationEnabled) {
            binding.navigationView.registerMapObserver(onMapLongClick)
            binding.navigationView.customizeViewOptions {
                enableMapLongClickIntercept = false
            }
        }

        // Hazard markers are drawn directly on the navigation map once it attaches.
        binding.navigationView.registerMapObserver(hazardMapObserver)

        val act = this
        // Add custom view binders
        binding.navigationView.customizeViewBinders {
            infoPanelEndNavigationButtonBinder =
                CustomInfoPanelEndNavButtonBinder(act)
        }

        MapboxNavigationApp.current()?.registerBannerInstructionsObserver(this.bannerInstructionObserver)
        MapboxNavigationApp.current()?.registerVoiceInstructionsObserver(this.voiceInstructionObserver)
        MapboxNavigationApp.current()?.registerOffRouteObserver(this.offRouteObserver)
        MapboxNavigationApp.current()?.registerRoutesObserver(this.routesObserver)
        MapboxNavigationApp.current()?.registerLocationObserver(locationObserver)
        MapboxNavigationApp.current()?.registerRouteProgressObserver(routeProgressObserver)
        MapboxNavigationApp.current()?.registerArrivalObserver(arrivalObserver)

        finishBroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                finish()
            }
        }

        addWayPointsBroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                //get waypoints
                val stops = intent.getSerializableExtra("waypoints") as? MutableList<Waypoint>
                val nextIndex = 1
                if (stops != null) {
                    //append to points
                    if (points.count() >= nextIndex)
                        points.addAll(nextIndex, stops)
                    else
                        points.addAll(stops)
                }
            }
        }

        ContextCompat.registerReceiver(
            this,
            finishBroadcastReceiver,
            IntentFilter(NavigationLauncher.KEY_STOP_NAVIGATION),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )

        ContextCompat.registerReceiver(
            this,
            addWayPointsBroadcastReceiver,
            IntentFilter(NavigationLauncher.KEY_ADD_WAYPOINTS),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )

        // Live reroute: rebuild the route from the supplied waypoints and swap it
        // into the running session via the existing requestRoutes() path.
        rerouteBroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                @Suppress("UNCHECKED_CAST")
                val stops = intent.getSerializableExtra("waypoints") as? MutableList<Waypoint>
                Log.d("EvacHazard", "reroute received: ${stops?.size ?: 0} waypoints")
                if (stops != null && stops.isNotEmpty()) {
                    val set = WaypointSet()
                    stops.forEach { set.add(it) }
                    requestRoutes(set)
                }
            }
        }

        // Live hazard markers: replace the drawn set with the supplied hazards.
        updateHazardsBroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val hz = intent.getSerializableExtra("hazards") as? ArrayList<*>
                pendingHazards = hz?.filterIsInstance<HashMap<*, *>>() ?: listOf()
                Log.d("EvacHazard", "received update: ${pendingHazards.size} hazards")
                renderHazards()
            }
        }

        ContextCompat.registerReceiver(
            this,
            rerouteBroadcastReceiver,
            IntentFilter(NavigationLauncher.KEY_REROUTE),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )

        ContextCompat.registerReceiver(
            this,
            updateHazardsBroadcastReceiver,
            IntentFilter(NavigationLauncher.KEY_UPDATE_HAZARDS),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )

        // TODO set the style Uri
        var styleUrlDay = FlutterMapboxNavigationPlugin.mapStyleUrlDay
        var styleUrlNight = FlutterMapboxNavigationPlugin.mapStyleUrlNight

        if (styleUrlDay == null) styleUrlDay = Style.MAPBOX_STREETS
        if (styleUrlNight == null) styleUrlNight = Style.DARK
        // set map style
        binding.navigationView.customizeViewStyles {}

        // set map style
        binding.navigationView.customizeViewOptions {
            mapStyleUriDay = styleUrlDay
            mapStyleUriNight = styleUrlNight
        }

        if (FlutterMapboxNavigationPlugin.enableFreeDriveMode) {
            binding.navigationView.api.routeReplayEnabled(FlutterMapboxNavigationPlugin.simulateRoute)
            binding.navigationView.api.startFreeDrive()
            return
        }

        val p = intent.getSerializableExtra("waypoints") as? MutableList<Waypoint>
        if (p != null) points = p
        points.map { waypointSet.add(it) }
        requestRoutes(waypointSet)

    }

    override fun onDestroy() {
        if (instance == this) instance = null
        try { unregisterReceiver(finishBroadcastReceiver) } catch (_: Exception) {}
        try { unregisterReceiver(addWayPointsBroadcastReceiver) } catch (_: Exception) {}
        try { unregisterReceiver(rerouteBroadcastReceiver) } catch (_: Exception) {}
        try { unregisterReceiver(updateHazardsBroadcastReceiver) } catch (_: Exception) {}
        super.onDestroy()
        if (FlutterMapboxNavigationPlugin.longPressDestinationEnabled) {
            binding.navigationView.unregisterMapObserver(onMapLongClick)
        }
        binding.navigationView.unregisterMapObserver(hazardMapObserver)
        binding.navigationView.removeListener(navigationStateListener)

        MapboxNavigationApp.current()?.unregisterBannerInstructionsObserver(this.bannerInstructionObserver)
        MapboxNavigationApp.current()?.unregisterVoiceInstructionsObserver(this.voiceInstructionObserver)
        MapboxNavigationApp.current()?.unregisterOffRouteObserver(this.offRouteObserver)
        MapboxNavigationApp.current()?.unregisterRoutesObserver(this.routesObserver)
        MapboxNavigationApp.current()?.unregisterLocationObserver(locationObserver)
        MapboxNavigationApp.current()?.unregisterRouteProgressObserver(routeProgressObserver)
        MapboxNavigationApp.current()?.unregisterArrivalObserver(arrivalObserver)
    }

    fun tryCancelNavigation() {
        if (isNavigationInProgress) {
            isNavigationInProgress = false
            sendEvent(MapBoxEvents.NAVIGATION_CANCELLED)
        }
    }

    private fun requestRoutes(waypointSet: WaypointSet) {
        sendEvent(MapBoxEvents.ROUTE_BUILDING)
        MapboxNavigationApp.current()!!.requestRoutes(
            routeOptions = RouteOptions
                .builder()
                .applyDefaultNavigationOptions(FlutterMapboxNavigationPlugin.navigationMode)
                .applyLanguageAndVoiceUnitOptions(this)
                .coordinatesList(waypointSet.coordinatesList())
                .waypointIndicesList(waypointSet.waypointsIndices())
                .waypointNamesList(waypointSet.waypointsNames())
                .language(FlutterMapboxNavigationPlugin.navigationLanguage)
                .alternatives(FlutterMapboxNavigationPlugin.showAlternateRoutes)
                .voiceUnits(FlutterMapboxNavigationPlugin.navigationVoiceUnits)
                .bannerInstructions(FlutterMapboxNavigationPlugin.bannerInstructionsEnabled)
                .voiceInstructions(FlutterMapboxNavigationPlugin.voiceInstructionsEnabled)
                .steps(true)
                .build(),
            callback = object : NavigationRouterCallback {
                override fun onCanceled(routeOptions: RouteOptions, routerOrigin: RouterOrigin) {
                    sendEvent(MapBoxEvents.ROUTE_BUILD_CANCELLED)
                }

                override fun onFailure(reasons: List<RouterFailure>, routeOptions: RouteOptions) {
                    sendEvent(MapBoxEvents.ROUTE_BUILD_FAILED)
                }

                override fun onRoutesReady(
                    routes: List<NavigationRoute>,
                    routerOrigin: RouterOrigin
                ) {
                    sendEvent(
                        MapBoxEvents.ROUTE_BUILT,
                        Gson().toJson(routes.map { it.directionsRoute.toJson() })
                    )
                    if (routes.isEmpty()) {
                        sendEvent(MapBoxEvents.ROUTE_BUILD_NO_ROUTES_FOUND)
                        return
                    }
                    Log.d("EvacHazard", "routes built: ${routes.size}; swapping active route")
                    // Canonical "replace the active route" — ensures a live swap when
                    // this fires mid-navigation (reroute), not just at trip start.
                    MapboxNavigationApp.current()?.setNavigationRoutes(routes)
                    binding.navigationView.api.routeReplayEnabled(FlutterMapboxNavigationPlugin.simulateRoute)
                    binding.navigationView.api.startActiveGuidance(routes)
                    // Re-layer hazard markers above the freshly-drawn route line.
                    bringHazardsToFront()
                }
            }
        )
    }


    // MultiWaypoint Navigation
    private fun addWaypoint(destination: Point, name: String?) {
        val originLocation = lastLocation
        val originPoint = originLocation?.let {
            Point.fromLngLat(it.longitude, it.latitude)
        } ?: return

        // we always start a route from the current location
        if (addedWaypoints.isEmpty) {
            addedWaypoints.add(Waypoint(originPoint))
        }

        if (!name.isNullOrBlank()) {
            // When you add named waypoints, the string you use here inside "" would be shown in `Maneuver` and played in `Voice` instructions.
            // In this example waypoint names will be visible in the logcat.
            addedWaypoints.add(Waypoint(name, destination))
        } else {
            // When you add silent waypoints, make sure it is followed by a regular or named waypoint, otherwise silent waypoint is treated as a regular waypoint
            addedWaypoints.add(Waypoint(destination, true))
        }

        // execute a route request
        // it's recommended to use the
        // applyDefaultNavigationOptions and applyLanguageAndVoiceUnitOptions
        // that make sure the route request is optimized
        // to allow for support of all of the Navigation SDK features
        MapboxNavigationApp.current()!!.requestRoutes(
            routeOptions = RouteOptions
                .builder()
                .applyDefaultNavigationOptions(FlutterMapboxNavigationPlugin.navigationMode)
                .applyLanguageAndVoiceUnitOptions(this)
                .coordinatesList(addedWaypoints.coordinatesList())
                .waypointIndicesList(addedWaypoints.waypointsIndices())
                .waypointNamesList(addedWaypoints.waypointsNames())
                .alternatives(FlutterMapboxNavigationPlugin.showAlternateRoutes)
                .build(),
            callback = object : NavigationRouterCallback {
                override fun onRoutesReady(
                    routes: List<NavigationRoute>,
                    routerOrigin: RouterOrigin
                ) {
                    sendEvent(
                        MapBoxEvents.ROUTE_BUILT,
                        Gson().toJson(routes.map { it.directionsRoute.toJson() })
                    )
                    binding.navigationView.api.routeReplayEnabled(true)
                    binding.navigationView.api.startActiveGuidance(routes)
                }

                override fun onFailure(
                    reasons: List<RouterFailure>,
                    routeOptions: RouteOptions
                ) {
                    sendEvent(MapBoxEvents.ROUTE_BUILD_FAILED)
                }

                override fun onCanceled(routeOptions: RouteOptions, routerOrigin: RouterOrigin) {
                    sendEvent(MapBoxEvents.ROUTE_BUILD_CANCELLED)
                }
            }
        )
    }

    // Resets the current route
    private fun resetCurrentRoute() {
//        if (mapboxNavigation.getRoutes().isNotEmpty()) {
//            mapboxNavigation.setRoutes(emptyList()) // reset route
//            addedWaypoints.clear() // reset stored waypoints
//        }
    }

    private fun setRouteAndStartNavigation(routes: List<DirectionsRoute>) {
        // set routes, where the first route in the list is the primary route that
        // will be used for active guidance
        // mapboxNavigation.setRoutes(routes)
    }

    private fun clearRouteAndStopNavigation() {
        // clear
        // mapboxNavigation.setRoutes(listOf())
    }


    /**
     * Helper class that keeps added waypoints and transforms them to the [RouteOptions] params.
     */
    private val addedWaypoints = WaypointSet()


    /**
     * Bindings to the Navigation Activity.
     */
    private lateinit var binding: NavigationActivityBinding// MapboxActivityTurnByTurnExperienceBinding


    /**
     * Gets notified with progress along the currently active route.
     */
    private val routeProgressObserver = RouteProgressObserver { routeProgress ->
        //Notify the client
        val progressEvent = MapBoxRouteProgressEvent(routeProgress)
        FlutterMapboxNavigationPlugin.distanceRemaining = routeProgress.distanceRemaining
        FlutterMapboxNavigationPlugin.durationRemaining = routeProgress.durationRemaining
        sendEvent(progressEvent)
    }

    private val arrivalObserver: ArrivalObserver = object : ArrivalObserver {
        override fun onFinalDestinationArrival(routeProgress: RouteProgress) {
            isNavigationInProgress = false
            sendEvent(MapBoxEvents.ON_ARRIVAL)
        }

        override fun onNextRouteLegStart(routeLegProgress: RouteLegProgress) {

        }

        override fun onWaypointArrival(routeProgress: RouteProgress) {

        }
    }

    /**
     * Gets notified with location updates.
     *
     * Exposes raw updates coming directly from the location services
     * and the updates enhanced by the Navigation SDK (cleaned up and matched to the road).
     */
    private val locationObserver = object : LocationObserver {
        override fun onNewLocationMatcherResult(locationMatcherResult: LocationMatcherResult) {
            lastLocation = locationMatcherResult.enhancedLocation
        }

        override fun onNewRawLocation(rawLocation: Location) {
            // no impl
        }
    }

    private val bannerInstructionObserver = BannerInstructionsObserver { bannerInstructions ->
        sendEvent(MapBoxEvents.BANNER_INSTRUCTION, bannerInstructions.primary().text())
    }

    private val voiceInstructionObserver = VoiceInstructionsObserver { voiceInstructions ->
        sendEvent(MapBoxEvents.SPEECH_ANNOUNCEMENT, voiceInstructions.announcement().toString())
    }

    private val offRouteObserver = OffRouteObserver { offRoute ->
        if (offRoute) {
            sendEvent(MapBoxEvents.USER_OFF_ROUTE)
        }
    }

    private val routesObserver = RoutesObserver { routeUpdateResult ->
        if (routeUpdateResult.navigationRoutes.isNotEmpty()) {
            sendEvent(MapBoxEvents.REROUTE_ALONG);
        }
    }

    /**
     * Creates/retains a [PointAnnotationManager] on the navigation [MapView] so
     * hazard markers can be drawn on top of the active route.
     */
    private val hazardMapObserver = object : MapViewObserver() {
        override fun onAttached(mapView: MapView) {
            hazardMapView = mapView
            // Defer manager creation + drawing until the style is loaded — adding
            // icon images/layers before that silently no-ops.
            mapView.getMapboxMap().getStyle {
                hazardAnnotationManager = mapView.annotations.createPointAnnotationManager()
                Log.d("EvacHazard", "map attached, manager created; pending=${pendingHazards.size}")
                renderHazards()
            }
        }

        override fun onDetached(mapView: MapView) {
            hazardAnnotationManager?.deleteAll()
            hazardAnnotationManager = null
            hazardMapView = null
        }
    }

    /**
     * Re-creates the hazard annotation layer so it sits ON TOP of the route line.
     * The nav SDK adds the route-line layer AFTER the map attaches, which would
     * otherwise cover markers created in onAttached. Called once a route is built.
     */
    private fun bringHazardsToFront() {
        val mapView = hazardMapView ?: return
        runOnUiThread {
            mapView.getMapboxMap().getStyle {
                hazardAnnotationManager?.let { mapView.annotations.removeAnnotationManager(it) }
                hazardAnnotationManager = mapView.annotations.createPointAnnotationManager()
                renderHazards()
            }
        }
    }

    /**
     * Redraws all hazard markers from [pendingHazards]. Safe to call before the
     * map attaches — it no-ops until [hazardAnnotationManager] exists.
     */
    private fun renderHazards() {
        val mgr = hazardAnnotationManager
        if (mgr == null) {
            Log.d("EvacHazard", "renderHazards: manager not ready, ${pendingHazards.size} pending")
            return
        }
        mgr.deleteAll()
        val options = mutableListOf<PointAnnotationOptions>()
        for (h in pendingHazards) {
            val lat = (h["lat"] as? Number)?.toDouble() ?: continue
            val lng = (h["lng"] as? Number)?.toDouble() ?: continue
            val severity = (h["severity"] as? String) ?: "moderate"
            options.add(
                PointAnnotationOptions()
                    .withPoint(Point.fromLngLat(lng, lat))
                    .withIconImage(hazardBitmap(severity))
                    .withIconSize(1.0)
            )
        }
        if (options.isNotEmpty()) mgr.create(options)
        Log.d("EvacHazard", "renderHazards: drew ${options.size} markers")
    }

    /**
     * Builds a simple severity-coloured circular marker bitmap. Avoids bundling
     * image assets — the marker is drawn programmatically.
     */
    private fun hazardBitmap(severity: String): Bitmap {
        val size = 96
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val fill = when (severity.lowercase()) {
            "critical" -> Color.parseColor("#E53935")
            "high"     -> Color.parseColor("#FB8C00")
            else       -> Color.parseColor("#FDD835")
        }
        val cx = size / 2f
        val cy = size / 2f
        val radius = size / 2f - 6f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        // Filled disc.
        paint.color = fill
        canvas.drawCircle(cx, cy, radius, paint)
        // White ring.
        paint.color = Color.WHITE
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 7f
        canvas.drawCircle(cx, cy, radius, paint)
        // White "!" so it clearly reads as a hazard, not a plain dot.
        paint.style = Paint.Style.FILL
        paint.color = Color.WHITE
        paint.textAlign = Paint.Align.CENTER
        paint.textSize = size * 0.62f
        paint.isFakeBoldText = true
        val fm = paint.fontMetrics
        canvas.drawText("!", cx, cy - (fm.ascent + fm.descent) / 2f, paint)
        return bmp
    }

    /**
     * Notifies with attach and detach events on [MapView]
     */
    private val onMapLongClick = object : MapViewObserver(), OnMapLongClickListener {

        override fun onAttached(mapView: MapView) {
            mapView.gestures.addOnMapLongClickListener(this)
        }

        override fun onDetached(mapView: MapView) {
            mapView.gestures.removeOnMapLongClickListener(this)
        }

        override fun onMapLongClick(point: Point): Boolean {
            ifNonNull(lastLocation) {
                val waypointSet = WaypointSet()
                waypointSet.add(Waypoint(Point.fromLngLat(it.longitude, it.latitude)))
                waypointSet.add(Waypoint(point))
                requestRoutes(waypointSet)
            }
            return false
        }
    }
}
