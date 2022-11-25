import leaflet from "../vendor/leaflet/leaflet";

// Images live in priv/static/images/leaflet
leaflet.Icon.Default.imagePath = "/images/leaflet/";

export default {
  mounted() {
    this.map = leaflet.map(this.el).setView([20, 0], 1);
    this.marker = leaflet.marker([0, 0]);

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

    this.map.on("click", (e) => {
      const lat = e.latlng.lat;
      const lon = e.latlng.lng;

      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        return;
      }

      this.pushEventTo(this.el, "map-clicked", { lat, lon });
    });

    this.handleEvent("set-marker", ({ coord }) => {
      if (coord && coord.lat && coord.lon) {
        this.marker.setLatLng([coord.lat, coord.lon]);
        this.marker.addTo(this.map);
      } else {
        this.marker.removeFrom(this.map);
      }
    });
  },
};
