import Toybox.Application;
import Toybox.Position;
import Toybox.System;
import Toybox.Math;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Graphics;
using Toybox.Time;

class RallyTripMeterApp extends Application.AppBase {

    var lastPosition = null;
    var lastPositionTime = 0;
    var totalDistance = 0.0;
    var lapDistance = 0.0;
    var currentSpeed = 0.0;
    var avgSpeed = 0.0;
    var startTime = 0.0;
    var view = null;

    const MAX_SPEED_JUMP = 20.0; // m/s
    const MIN_VALID_DISTANCE = 0.5; // meters
    const ALPHA = 0.5; // smoothing factor for EMA

    function onStart(state) {
        startTime = Time.now().value();
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onLocation));
    }

    function onStop(state) {
        // GPS cleanup is automatic
    }

    function getInitialView() {
        view = new RallyTripMeterView(self);
        var delegate = new RallyInputDelegate(self);
        return [view, delegate];
    }

    function abs(x as Number) as Number {
        if (x < 0) {
            return -x;
        } else {
            return x;
        }
    }

    function onLocation(info as Position.Info) as Void {
        if (info == null or info.position == null) {
            return;
        }

        var current = info.position.toDegrees();
        var currentTime = Time.now().value(); // Use system time fallback

        if (lastPosition != null) {
            var lat1 = lastPosition[0];
            var lon1 = lastPosition[1];
            var lat2 = current[0];
            var lon2 = current[1];

            var RAD = Math.PI / 180.0;
            var dlat = (lat2 - lat1) * RAD;
            var dlon = (lon2 - lon1) * RAD;
            var a = Math.pow(Math.sin(dlat / 2), 2) +
                    Math.cos(lat1 * RAD) * Math.cos(lat2 * RAD) *
                    Math.pow(Math.sin(dlon / 2), 2);
            var c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a));
            var distance = 6371000.0 * c; // meters

            if (distance < MIN_VALID_DISTANCE) {
                return;
            }

            var deltaTime = 1.0;
            if (lastPositionTime > 0) {
                deltaTime = currentTime - lastPositionTime;
                if (deltaTime < 0.5) {
                    return;
                }
            }

            var instSpeed = distance / deltaTime;

            // Use device speed if available and reasonable
            if ((info has :speed) and (info.speed != null) and (info.speed > 0)) {
                instSpeed = info.speed;
            }

            // Reject unrealistic spikes
            if ((currentSpeed > 0.0) and (abs(instSpeed - currentSpeed) > MAX_SPEED_JUMP)) {
                return;
            }

            // EMA smoothing
            if (currentSpeed == 0.0) {
                currentSpeed = instSpeed;
            } else {
                currentSpeed = ALPHA * instSpeed + (1 - ALPHA) * currentSpeed;
            }

            totalDistance += distance;
            lapDistance += distance;

            var elapsedSeconds = currentTime - startTime;
            if (elapsedSeconds > 0) {
                avgSpeed = totalDistance / elapsedSeconds;
            }

            if (view != null) {
                view.setValues(
                    totalDistance,
                    lapDistance,
                    currentSpeed * 3.6, // km/h
                    avgSpeed * 3.6      // km/h
                );
                WatchUi.requestUpdate();
            }

            // Optional: debugging
            // System.println("Speed: " + (instSpeed * 3.6).format("%.2f") + " km/h, Distance: " + distance.format("%.2f") + " m, dt: " + deltaTime.format("%.2f") + " s");
        }

        lastPosition = current;
        lastPositionTime = currentTime;
    }

    function reset() {
        totalDistance = 0.0;
        lapDistance = 0.0;
        lastPosition = null;
        lastPositionTime = 0;
        currentSpeed = 0.0;
        avgSpeed = 0.0;
        startTime = Time.now().value();

        if (view != null) {
            view.setValues(0.0, 0.0, 0.0, 0.0);
            WatchUi.requestUpdate();
        }
    }

    function saveLap() {
        lapDistance = 0.0;
    }
}

class RallyInputDelegate extends WatchUi.BehaviorDelegate {
    var app;

    function initialize(appRef) {
        BehaviorDelegate.initialize();
        app = appRef;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        app.saveLap();
        return true;
    }

    function onHold(evt as WatchUi.ClickEvent) as Boolean {
        app.reset();
        return true;
    }
}

class RallyTripMeterView extends WatchUi.View {
    var app;
    var totalDistance = 0.0;
    var lapDistance = 0.0;
    var currentSpeed = 0.0;
    var avgSpeed = 0.0;

    function initialize(appRef) {
        View.initialize();
        app = appRef;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        app.saveLap();
        return true;
    }

    function onHold(evt as WatchUi.ClickEvent) as Boolean {
        app.reset();
        return true;
    }

    function setValues(totalD, lapD, curS, avgS) {
        totalDistance = totalD;
        lapDistance = lapD;
        currentSpeed = curS;
        avgSpeed = avgS;
    }

    function onUpdate(dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var distKm = totalDistance / 1000.0;
        var lapKm = lapDistance / 1000.0;
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        dc.drawText(centerX, centerY - 160, Graphics.FONT_LARGE,
            distKm.format("%.2f") + " km",
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(centerX, centerY - 100, Graphics.FONT_MEDIUM,
            "-" + lapKm.format("%.2f"),
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(centerX, centerY + 50, Graphics.FONT_LARGE,
            currentSpeed.format("%.0f") + " km/h",
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.drawText(centerX, centerY + 110, Graphics.FONT_MEDIUM,
            "~" + avgSpeed.format("%.0f"),
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}
