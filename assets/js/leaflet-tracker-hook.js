import leaflet from "../vendor/leaflet/leaflet";
import { GreatCircle } from "../vendor/arc";

// Images live in priv/static/images/leaflet
leaflet.Icon.Default.imagePath = "/images/leaflet/";

//
// Satellite icon
//
const SAT_ICON_SIZE = 40;
const SAT_ICON_SIZE_HOVER = 44;

const satIconOptions = {
  iconUrl: "/images/sat-marker.png",
  iconSize: [SAT_ICON_SIZE, SAT_ICON_SIZE],
  iconAnchor: [SAT_ICON_SIZE / 2 + 1, SAT_ICON_SIZE / 2 + 1],
  shadowUrl: "/images/sat-marker-shadow.png",
  shadowSize: [SAT_ICON_SIZE, SAT_ICON_SIZE],
  shadowAnchor: [SAT_ICON_SIZE / 2 - 1, SAT_ICON_SIZE / 2 - 1],
};

const satIcon = leaflet.icon(satIconOptions);
const satIconHover = leaflet.icon({
  ...satIconOptions,
  iconSize: [SAT_ICON_SIZE_HOVER, SAT_ICON_SIZE_HOVER],
  iconAnchor: [SAT_ICON_SIZE_HOVER / 2 + 2, SAT_ICON_SIZE_HOVER / 2 + 2],
  shadowSize: [SAT_ICON_SIZE_HOVER, SAT_ICON_SIZE_HOVER],
  shadowAnchor: [SAT_ICON_SIZE_HOVER / 2 - 2, SAT_ICON_SIZE_HOVER / 2 - 2],
});

//
// Footprint
//
const footprintStyle = {
  stroke: true,
  weight: 1,
  opacity: 0.3,
  color: "#374151", // gray-700
  fillOpacity: 0.1,
};

const highlightedFootprintStyle = {
  ...footprintStyle,
  stroke: true,
  opacity: 0.7,
  fillOpacity: 0.4,
};

//
// Hook
//
export default {
  mounted() {
    this.sats = {};

    this.map = leaflet
      .map(this.el, {
        worldCopyJump: true,
        attributionControl: false,
      })
      .setView([20, 0], 1);

    this.observers = JSON.parse(this.el.dataset.observers).map((coord) => {
      const marker = leaflet.marker(coord).addTo(this.map);
      marker.addTo(this.map);
      const polyline = leaflet.polyline([], {
        color: "#f59e0b", // amber-500
      });
      return { coord, marker, polyline };
    });

    leaflet
      .tileLayer(
        "https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}",
        {
          attribution:
            'Map data &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, Imagery © <a href="https://www.mapbox.com/">Mapbox</a>',
          maxZoom: 18,
          id: "mapbox/outdoors-v12",
          tileSize: 512,
          zoomOffset: -1,
          accessToken: this.el.dataset.mapboxAccessToken,
          noWrap: false,
          bounds: [
            [-90, -180],
            [90, 180],
          ],
        }
      )
      .addTo(this.map);

    // Static ground track for a single pass, styled like the polar plot path:
    // blue line with a circle at AOS and an arrowhead at LOS. Drawn at ±360°
    // offsets so it survives worldCopyJump like the markers do.
    const groundTrack = JSON.parse(this.el.dataset.groundTrack || "[]");
    if (groundTrack.length > 1) {
      const trackColor = "#2563eb"; // blue-600

      // Screen-space bearing of the last segment (Mercator is conformal, so
      // the angle is the same at every zoom)
      const p1 = this.map.project(groundTrack[groundTrack.length - 2], 0);
      const p2 = this.map.project(groundTrack[groundTrack.length - 1], 0);
      const angle = (Math.atan2(p2.y - p1.y, p2.x - p1.x) * 180) / Math.PI;

      const arrowIcon = leaflet.divIcon({
        className: "",
        iconSize: [18, 18],
        iconAnchor: [9, 9],
        html: `<svg width="18" height="18" viewBox="0 0 18 18" style="transform: rotate(${angle}deg)">
                 <path d="M 17 9 L 2 2 L 5 9 L 2 16 Z" fill="${trackColor}"/>
               </svg>`,
      });

      [-360, 0, 360].forEach((offset) => {
        const shifted = groundTrack.map(([lat, lon]) => [lat, lon + offset]);

        leaflet
          .polyline(shifted, {
            color: trackColor,
            weight: 4,
            opacity: 0.8,
          })
          .addTo(this.map);

        leaflet
          .circleMarker(shifted[0], {
            radius: 5,
            color: trackColor,
            weight: 2,
            fillColor: trackColor,
            fillOpacity: 1,
          })
          .addTo(this.map);

        leaflet
          .marker(shifted[shifted.length - 1], {
            icon: arrowIcon,
            interactive: false,
          })
          .addTo(this.map);
      });

      this.map.fitBounds(leaflet.latLngBounds(groundTrack), {
        padding: [20, 20],
      });
    }

    this.handleEvent("set-sat-positions", ({ positions }) => {
      positions.forEach((position) => this.updateSatPosition(position));
      this.updateLayers();
    });
  },

  updateSatPosition(params) {
    // Find and update the sat object
    const sat = this.sats[params.satId] || this.createSat(params);
    Object.assign(sat, params);

    // Update the layers
    const [lat, lon] = params.coord;

    [-360, 0, 360].forEach((offset, i) => {
      sat.markers[i].setLatLng([lat, lon + offset]);
    });

    // Don't bother updating the radius, it's mostly the same, and it's a lot of extra math and CPU
    // sat.footprint.setRadius(params.footprintRadius * 1000);
    sat.footprint.setLatLng(params.coord);
  },

  createSat(params) {
    const footprint = leaflet.greatCircle(params.coord, {
      ...footprintStyle,
      radius: params.footprintRadius * 1000,
      degStep: 10.0,
    });
    footprint.addTo(this.map);

    const markers = [-360, 0, 360].map((offset) => {
      const [lat, lon] = params.coord;
      const marker = leaflet.marker([lat, lon + offset], { icon: satIcon });
      marker.bindTooltip(params.satName, {
        direction: "top",
        offset: [0, -SAT_ICON_SIZE / 2],
      });

      // Make the marker bigger when hovered
      marker.on("mouseover", () => {
        marker.setIcon(satIconHover);
        sat.hovered = true;
        this.updateLayers();
      });
      marker.on("mouseout", () => {
        marker.setIcon(satIcon);
        sat.hovered = false;
        this.updateLayers();
      });
      marker.on("click", () => {
        this.pushEvent("sat-clicked", { sat_id: params.satId });
      });
      marker.addTo(this.map);

      return marker;
    });

    const sat = {
      ...params,
      markers,
      footprint,
      hovered: false,
    };

    this.sats[params.satId] = sat;
    return sat;
  },

  getHighlightedSat() {
    const hoveredSats = Object.values(this.sats).filter((sat) => sat.hovered);
    const selectedSats = Object.values(this.sats).filter((sat) => sat.selected);

    if (hoveredSats.length == 1) {
      return hoveredSats[0];
    } else if (selectedSats.length == 1) {
      return selectedSats[0];
    }

    return null;
  },

  updateLayers() {
    // Update observer lines
    const showObserverLines = this.el.dataset.observerLines !== "false";
    this.observers.forEach((observer) => {
      if (showObserverLines && this.getHighlightedSat()) {
        const coords = [observer.coord, this.getHighlightedSat().coord];
        observer.polyline.setLatLngs(
          greatCircleCoords(coords[0], coords[1], 30)
        );
        observer.polyline.addTo(this.map);
      } else {
        observer.polyline.removeFrom(this.map);
      }
    });

    // Update footprints
    Object.values(this.sats).forEach((sat) => {
      if (sat.hovered || sat.selected) {
        sat.footprint.setStyle(highlightedFootprintStyle);
      } else {
        sat.footprint.setStyle(footprintStyle);
      }
    });
  },
};

function greatCircleCoords(start, end, count) {
  // x is longitude, y is latitude
  start = { x: start[1], y: start[0] };
  end = { x: end[1], y: end[0] };

  const generator = new GreatCircle(start, end);

  // Swap (x, y) to (lat, lon)
  const output = generator
    .Arc(count)
    .geometries[0].coords.map((xy) => [xy[1], xy[0]]);

  // Unwrap longitude
  for (let i = 1; i < output.length; i++) {
    const [lat, lon] = output[i];
    const [prevLat, prevLon] = output[i - 1];
    if (Math.abs(lon - prevLon) > 180) {
      output[i][1] += lon > prevLon ? -360 : 360;
    }
  }

  return output;
}
