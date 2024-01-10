import leaflet from "../vendor/leaflet/leaflet";
import { GreatCircle } from "../vendor/arc";

// Images live in priv/static/images/leaflet
leaflet.Icon.Default.imagePath = "/images/leaflet/";

const satIcon = leaflet.icon({
  iconUrl: "/images/sat-marker.png",
  iconSize: [64, 64],
  iconAnchor: [32, 32],
  shadowUrl: "/images/sat-marker-shadow.png",
  shadowSize: [64, 64],
  shadowAnchor: [29, 29],
});

export default {
  mounted() {
    this.satCoord = null;
    this.map = leaflet.map(this.el).setView([0, 0], 1);

    this.observers = JSON.parse(this.el.dataset.observers).map((coord) => {
      const marker = leaflet.marker(coord).addTo(this.map);
      marker.addTo(this.map);
      const polyline = leaflet.polyline([]);
      return { coord, marker, polyline };
    });

    this.satMarker = leaflet.marker([0, 0], { icon: satIcon });
    this.circle = leaflet.greatCircle([0, 0], { radius: 0 });
    this.circle.addTo(this.map);

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

    this.handleEvent("set-sat-position", ({ coord, footprintRadius }) => {
      this.satCoord = coord;
      this.updateObserverLines();

      this.updateMarker("satMarker", coord);

      if (coord && footprintRadius) {
        this.circle.setLatLng([coord.lat, coord.lon]);
        this.circle.setRadius(footprintRadius * 1000);
        this.circle.addTo(this.map);
      } else {
        this.circle.removeFrom(this.map);
      }
    });
  },

  updateObserverLines() {
    this.observers.forEach((observer) => {
      if (this.satCoord) {
        const coords = [observer.coord, [this.satCoord.lat, this.satCoord.lon]];
        observer.polyline.setLatLngs(
          greatCircleCoords(coords[0], coords[1], 30)
        );
        observer.polyline.addTo(this.map);
      } else {
        observer.polyline.removeFrom(this.map);
      }
    });
  },

  updateMarker(name, coord) {
    if (coord) {
      this[name].setLatLng([coord.lat, coord.lon]);
      this[name].addTo(this.map);
    } else {
      this[name] && this[name].removeFrom(this.map);
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
