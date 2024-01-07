import leaflet from "../vendor/leaflet/leaflet";

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
    this.observerCoord = null;
    this.activatorCoord = null;
    this.map = leaflet.map(this.el).setView([0, 0], 1);
    this.satMarker = leaflet.marker([0, 0], { icon: satIcon });
    this.observerMarker = leaflet.marker([0, 0]);
    this.activatorMarker = leaflet.marker([0, 0]);
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
          noWrap: true,
          bounds: [
            [-90, -180],
            [90, 180],
          ],
        }
      )
      .addTo(this.map);

    this.handleEvent("set-sat-position", ({ coord, footprintRadius }) => {
      this.satCoord = coord;
      this.updateLines();

      this.updateMarker("satMarker", coord);

      if (coord && footprintRadius) {
        this.circle.setLatLng([coord.lat, coord.lon]);
        this.circle.setRadius(footprintRadius * 1000);
        this.circle.addTo(this.map);
      } else {
        this.circle.removeFrom(this.map);
      }
    });

    this.handleEvent("set-observer-position", ({ coord }) => {
      this.observerCoord = coord;
      this.updateMarker("observerMarker", coord);
      this.updateLines();
    });

    this.handleEvent("set-activator-position", ({ coord }) => {
      this.activatorCoord = coord;
      this.updateMarker("activatorMarker", coord);
      this.updateLines();
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

  updateLines() {
    this.updateLineToSat("observerPolyline", this.observerCoord);
    this.updateLineToSat("activatorPolyline", this.activatorCoord);
  },

  updateLineToSat(name, groundCoord) {
    if (groundCoord && this.satCoord) {
      const coords = [
        [groundCoord.lat, groundCoord.lon],
        [this.satCoord.lat, this.satCoord.lon],
      ];
      this[name] = this[name] || leaflet.polyline(coords);
      this[name].setLatLngs(coords);
      this[name].addTo(this.map);
    } else {
      this[name] && this[name].removeFrom(this.map);
      this[name] = null;
    }
  },
};
