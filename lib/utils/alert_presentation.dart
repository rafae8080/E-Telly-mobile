import 'package:flutter/material.dart';
import '../constants.dart';

/// Resident-facing presentation layer for alerts (mobile).
///
/// The backend already classifies every auto-generated alert with a `severity`
/// (`watch` / `warning` / `critical` / `evacuate`) that is *derived from* the
/// official PAGASA Color-Coded Rainfall Advisory thresholds — Yellow 7.5 mm/hr,
/// Orange 15 mm/hr, Red 30 mm/hr (see `server/services/floodAlerts.js` and
/// `landslideAlerts.js`). Typhoon severity comes from PAGASA 2022 wind
/// categories and earthquake severity from PHIVOLCS-aligned magnitude bands.
///
/// This file does NOT invent any new risk assessment. It only re-presents the
/// existing severity + hazard type as plain language a resident can act on —
/// the Yellow / Orange / Red mindset — instead of the CDRRMO-grade technical
/// description (mm/hr, soil moisture %, source DOIs).
///
/// PAGASA band ↔ action level mapping (faithful):
///   watch    → 🟡 Advisory      ("be aware")
///   warning  → 🟠 Be Prepared   ("be prepared / ready to evacuate")
///   critical → 🔴 Emergency     ("take action")
///   evacuate → 🔴 Evacuate Now  ("evacuate immediately")
enum AlertActionLevel { advisory, bePrepared, emergency, evacuate }

class AlertPresentation {
  /// Maps the raw backend severity to a resident action level.
  static AlertActionLevel levelFromSeverity(String rawSeverity) {
    switch (rawSeverity) {
      case 'evacuate':
        return AlertActionLevel.evacuate;
      case 'critical':
        return AlertActionLevel.emergency;
      case 'warning':
        return AlertActionLevel.bePrepared;
      case 'watch':
      default:
        return AlertActionLevel.advisory;
    }
  }

  static String bandLabel(AlertActionLevel level) {
    switch (level) {
      case AlertActionLevel.advisory:
        return 'ADVISORY';
      case AlertActionLevel.bePrepared:
        return 'BE PREPARED';
      case AlertActionLevel.emergency:
        return 'EMERGENCY';
      case AlertActionLevel.evacuate:
        return 'EVACUATE NOW';
    }
  }

  static Color bandColor(AlertActionLevel level) {
    switch (level) {
      case AlertActionLevel.advisory:
        return ET_YELLOW; // 🟡
      case AlertActionLevel.bePrepared:
        return ET_ORANGE; // 🟠
      case AlertActionLevel.emergency:
      case AlertActionLevel.evacuate:
        return ET_RED; // 🔴
    }
  }

  static IconData bandIcon(AlertActionLevel level) {
    switch (level) {
      case AlertActionLevel.advisory:
        return Icons.info_outline;
      case AlertActionLevel.bePrepared:
        return Icons.warning_amber_rounded;
      case AlertActionLevel.emergency:
        return Icons.error_outline;
      case AlertActionLevel.evacuate:
        return Icons.directions_run;
    }
  }

  /// Machine-generated sources whose CDRRMO-grade technical description should
  /// be replaced with plain resident text:
  ///   - 'system' : flood / rainfall / landslide (Open-Meteo + PAGASA engine)
  ///   - 'USGS'   : earthquakes (USGS FDSN)
  ///   - 'GDACS'  : typhoon / volcano (GDACS feeds)
  /// Human-authored sources ('CDRRMO', 'Barangay' manual alerts, and
  /// 'residents' community-report alerts) keep their original wording.
  static const Set<String> _machineSources = {'system', 'USGS', 'GDACS'};

  /// Whether the alert was produced by an automated hazard feed (rewrite to
  /// resident text) vs. written by a human (keep verbatim).
  static bool isAutoAlert(String source, bool isManual) {
    if (isManual) return false;
    return _machineSources.contains(source);
  }

  /// Groups the many backend hazard types into a handful of message families.
  static String _family(String rawType) {
    switch (rawType) {
      case 'flood':
      case 'rainfall':
      case 'storm':
        return 'flood';
      case 'landslide':
      case 'lahar':
        return 'landslide';
      case 'typhoon':
        return 'typhoon';
      case 'earthquake':
        return 'earthquake';
      case 'volcano':
        return 'volcano';
      default:
        return 'generic';
    }
  }

  /// Plain-language "what is happening" line for residents.
  static String residentMessage(String rawType, String rawSeverity) {
    final level = levelFromSeverity(rawSeverity);
    switch (_family(rawType)) {
      case 'flood':
        switch (level) {
          case AlertActionLevel.advisory:
            return 'Flooding is possible in low-lying areas and along river channels.';
          case AlertActionLevel.bePrepared:
            return 'Flooding is alarming and landslides are possible.';
          case AlertActionLevel.emergency:
            return 'Serious flooding is likely and can be damaging.';
          case AlertActionLevel.evacuate:
            return 'Life-threatening flooding is expected in low-lying areas.';
        }
      case 'landslide':
        switch (level) {
          case AlertActionLevel.advisory:
            return 'The ground is getting saturated. Landslides are possible on slopes.';
          case AlertActionLevel.bePrepared:
            return 'Landslides are a real threat on hills and steep slopes.';
          case AlertActionLevel.emergency:
            return 'Landslides are likely on saturated slopes.';
          case AlertActionLevel.evacuate:
            return 'Life-threatening landslides are expected on slopes.';
        }
      case 'typhoon':
        switch (level) {
          case AlertActionLevel.advisory:
            return 'A tropical storm is near. Strong winds and rain are expected.';
          case AlertActionLevel.bePrepared:
            return 'A severe storm is approaching. Dangerous winds are expected.';
          case AlertActionLevel.emergency:
            return 'Typhoon conditions — destructive winds are expected.';
          case AlertActionLevel.evacuate:
            return 'Super typhoon — life-threatening winds and storm surge.';
        }
      case 'earthquake':
        switch (level) {
          case AlertActionLevel.advisory:
            return 'An earthquake occurred nearby. Aftershocks are possible.';
          case AlertActionLevel.bePrepared:
            return 'A strong earthquake occurred nearby. Aftershocks are likely.';
          case AlertActionLevel.emergency:
            return 'A strong earthquake struck. Expect aftershocks.';
          case AlertActionLevel.evacuate:
            return 'A major earthquake struck — buildings may be unsafe.';
        }
      case 'volcano':
        switch (level) {
          case AlertActionLevel.advisory:
            return 'Volcanic activity detected. Ashfall is possible.';
          case AlertActionLevel.bePrepared:
            return 'Increased volcanic activity. Ashfall is likely.';
          case AlertActionLevel.emergency:
            return 'Significant eruption activity. Ashfall is expected.';
          case AlertActionLevel.evacuate:
            return 'Dangerous eruption — the danger zone is unsafe.';
        }
      default: // generic
        switch (level) {
          case AlertActionLevel.advisory:
            return 'A hazard is being monitored in your area.';
          case AlertActionLevel.bePrepared:
            return 'A hazard may affect your area. Be ready.';
          case AlertActionLevel.emergency:
            return 'A serious hazard is affecting your area.';
          case AlertActionLevel.evacuate:
            return 'A life-threatening hazard is present in your area.';
        }
    }
  }

  /// Imperative "what to do" line for residents.
  static String actionText(String rawType, String rawSeverity) {
    final level = levelFromSeverity(rawSeverity);
    switch (_family(rawType)) {
      case 'flood':
        switch (level) {
          case AlertActionLevel.advisory:
            return 'Stay aware and monitor official updates.';
          case AlertActionLevel.bePrepared:
            return 'Ready your go-bag and watch for evacuation orders.';
          case AlertActionLevel.emergency:
            return 'Move to higher ground now and avoid floodwaters.';
          case AlertActionLevel.evacuate:
            return 'Evacuate immediately to the nearest evacuation center.';
        }
      case 'landslide':
        switch (level) {
          case AlertActionLevel.advisory:
            return 'Stay away from steep slopes and monitor updates.';
          case AlertActionLevel.bePrepared:
            return 'Avoid slope areas and prepare to leave.';
          case AlertActionLevel.emergency:
            return 'Move away from hillsides to safe ground now.';
          case AlertActionLevel.evacuate:
            return 'Evacuate slope areas immediately.';
        }
      case 'typhoon':
        switch (level) {
          case AlertActionLevel.advisory:
            return 'Secure loose objects and prepare emergency supplies.';
          case AlertActionLevel.bePrepared:
            return 'Ready your go-bag and be ready to evacuate.';
          case AlertActionLevel.emergency:
            return 'Stay indoors, away from windows.';
          case AlertActionLevel.evacuate:
            return 'Evacuate now if you are in a vulnerable area.';
        }
      case 'earthquake':
        switch (level) {
          case AlertActionLevel.advisory:
            return 'Stay alert and check your surroundings for hazards.';
          case AlertActionLevel.bePrepared:
            return 'Secure heavy objects and be ready for aftershocks.';
          case AlertActionLevel.emergency:
            return 'Drop, Cover, and Hold On. Watch for aftershocks.';
          case AlertActionLevel.evacuate:
            return 'Move to open ground, away from buildings and power lines.';
        }
      case 'volcano':
        switch (level) {
          case AlertActionLevel.advisory:
            return 'Keep masks ready and monitor PHIVOLCS updates.';
          case AlertActionLevel.bePrepared:
            return 'Stay indoors and prepare masks and clean water.';
          case AlertActionLevel.emergency:
            return 'Stay indoors, wear a mask, and cover water sources.';
          case AlertActionLevel.evacuate:
            return 'Evacuate the danger zone immediately.';
        }
      default: // generic
        switch (level) {
          case AlertActionLevel.advisory:
            return 'Stay aware and monitor official updates.';
          case AlertActionLevel.bePrepared:
            return 'Prepare your go-bag and stay alert.';
          case AlertActionLevel.emergency:
            return 'Follow official instructions and move to safety.';
          case AlertActionLevel.evacuate:
            return 'Evacuate immediately and follow official instructions.';
        }
    }
  }
}
