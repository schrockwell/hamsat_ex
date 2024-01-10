import leaflet from "../vendor/leaflet/leaflet";
import { GreatCircle } from "../vendor/arc";

// Images live in priv/static/images/leaflet
leaflet.Icon.Default.imagePath = "/images/leaflet/";

const satIconOptions = {
  iconUrl: "/images/sat-marker.png",
  iconSize: [64, 64],
  iconAnchor: [32, 32],
  shadowUrl: "/images/sat-marker-shadow.png",
  shadowSize: [64, 64],
  shadowAnchor: [29, 29],
};

const satIcon = leaflet.icon(satIconOptions);
const satIconHover = leaflet.icon({
  ...satIconOptions,
  iconSize: [72, 72],
  iconAnchor: [36, 36],
  shadowSize: [72, 72],
  shadowAnchor: [33, 33],
});

export default {
  mounted() {
    this.sats = {};
    this.map = leaflet
      .map(this.el, { worldCopyJump: true })
      .setView([20, 0], 1);

    this.observers = JSON.parse(this.el.dataset.observers).map((coord) => {
      const marker = leaflet.marker(coord).addTo(this.map);
      marker.addTo(this.map);
      const polyline = leaflet.polyline([]);
      return { coord, marker, polyline };
    });

    this.selectedFootprint = leaflet.greatCircle([0, 0], { radius: 0 });

    leaflet
      .tileLayer(
        "https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}",
        {
          attribution:
            'Map data &copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, Imagery © <a href="https://www.mapbox.com/">Mapbox</a>',
          maxZoom: 18,
          id: "mapbox/streets-v11",
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

    this.handleEvent("set-sat-positions", ({ positions }) => {
      positions.forEach((position) => this.updateSatPosition(position));
      this.updateObserverLines();
      this.updateSelectedSat();
    });
  },

  selectedSatPosition() {
    // TODO: Make this configurable from the LiveComponent
    return Object.values(this.sats)[0];
  },

  updateSatPosition({ satId, coord, footprintRadius }) {
    let sat = this.sats[satId];

    if (!sat) {
      const marker = leaflet.marker(coord, { icon: satIcon });

      // Make the marker bigger when hovered
      marker.on("mouseover", () => marker.setIcon(satIconHover));
      marker.on("mouseout", () => marker.setIcon(satIcon));

      sat = {
        satId,
        coord,
        footprintRadius,
        marker,
      };
      sat.marker.addTo(this.map);
      this.sats[satId] = sat;
    }

    sat.coord = coord;
    sat.footprintRadius = footprintRadius;
    sat.marker.setLatLng(coord);
  },

  updateObserverLines() {
    this.observers.forEach((observer) => {
      if (this.selectedSatPosition()) {
        const coords = [observer.coord, this.selectedSatPosition().coord];
        observer.polyline.setLatLngs(
          greatCircleCoords(coords[0], coords[1], 30)
        );
        observer.polyline.addTo(this.map);
      } else {
        observer.polyline.removeFrom(this.map);
      }
    });
  },

  updateSelectedSat() {
    const sat = this.selectedSatPosition();

    if (sat) {
      this.selectedFootprint.addTo(this.map);
      this.selectedFootprint.setLatLng(sat.coord);
      this.selectedFootprint.setRadius(sat.footprintRadius * 1000);
    } else {
      this.selectedFootprint.removeFrom(this.map);
    }
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
