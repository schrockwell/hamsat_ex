const GUIDE_COLOR = "#CCCCCC";
const SATELLITE_COLOR = "#2563EB"; // blue-700
const HIDDEN_SATELLITE_COLOR = "rgb(220 38 38)"; // red-600
const PATH_COLOR = SATELLITE_COLOR; // emerald-500
const CARDINAL_COLOR = "#000000";
const TEXT_SIZE = "16px";
const MIN_ELEVATION = -10;
const START_HEAD_SIZE = 8;
const ARROW_SIZE = 20;
const PADDING = 60;
const CARDINAL_LABEL_ELEVATION = -25;

export default {
  mounted() {
    const path = JSON.parse(this.el.dataset.path).filter(
      (coord) => coord.el >= 0
    );

    const { svg, moveSatellite } = createSatelliteSVG(path, {
      azimuth: 45,
      elevation: 45,
    });
    this.el.appendChild(svg);

    this.handleEvent("move_satellite", ({ id, az, el }) => {
      if (id !== this.el.id) return;
      moveSatellite(az, el);
    });
  },
};

function createSatelliteSVG(pathData, currentPosition) {
  const width = 500;
  const height = 500;
  const svgns = "http://www.w3.org/2000/svg";
  const centerX = width / 2;
  const centerY = height / 2;
  const maxRadius = Math.min(width, height) / 2 - PADDING; // Adjust to bring circles inwards

  // Create SVG element
  const svg = document.createElementNS(svgns, "svg");
  svg.setAttribute("width", "100%");
  svg.setAttribute("height", "100%");
  svg.setAttribute("viewBox", `0 0 ${width} ${height}`);

  // Function to convert (azimuth, elevation) to (x, y)
  function convertCoords(azimuth, elevation) {
    const adjustedAzimuth = azimuth - 90; // Move 0° to the top
    const radius = ((90 - elevation) / (90 - MIN_ELEVATION)) * maxRadius; // Adjust scale for -10° to 90°
    const radian = adjustedAzimuth * (Math.PI / 180);

    const x = centerX - radius * Math.cos(radian); // Flip x-axis
    const y = centerY + radius * Math.sin(radian);
    return { x, y };
  }

  // Add Circles
  function addElevationCircles() {
    const elevations = [0, 30, 60];
    elevations.forEach((elevation) => {
      const circle = document.createElementNS(svgns, "circle");
      const radius = ((90 - elevation) / (90 - MIN_ELEVATION)) * maxRadius;
      circle.setAttribute("cx", centerX);
      circle.setAttribute("cy", centerY);
      circle.setAttribute("r", radius);
      circle.setAttribute("stroke", GUIDE_COLOR);
      circle.setAttribute("fill", "none");
      svg.appendChild(circle);

      // Add label
      const label = document.createElementNS(svgns, "text");
      label.setAttribute("x", centerX + radius + 5);
      label.setAttribute("y", centerY - 5);
      label.setAttribute("alignment-baseline", "middle");
      label.setAttribute("fill", GUIDE_COLOR);
      label.setAttribute("font-size", TEXT_SIZE);
      label.textContent = `${elevation}°`;
      svg.appendChild(label);
    });
  }
  // Add Intercardinal Directions
  function addIntercardinalDirections() {
    const directions = [
      "0°",
      "45°",
      "90°",
      "135°",
      "180°",
      "225°",
      "270°",
      "315°",
    ];
    const angles = [0, 45, 90, 135, 180, 225, 270, 315];

    directions.forEach((dir, index) => {
      const angle = angles[index];
      const line = document.createElementNS(svgns, "line");
      const { x, y } = convertCoords(angle, MIN_ELEVATION);
      line.setAttribute("x1", centerX);
      line.setAttribute("y1", centerY);
      line.setAttribute("x2", x);
      line.setAttribute("y2", y);
      line.setAttribute("stroke", "#CCCCCC");
      svg.appendChild(line);

      const labelPos = convertCoords(angle, CARDINAL_LABEL_ELEVATION); // Position labels just outside the innermost circle
      const label = document.createElementNS(svgns, "text");
      label.setAttribute("x", labelPos.x);
      label.setAttribute("y", labelPos.y);
      label.setAttribute("text-anchor", "middle");
      label.setAttribute("dominant-baseline", "middle");
      label.setAttribute("font-size", TEXT_SIZE);
      label.setAttribute("font-weight", "medium");
      label.setAttribute("fill", CARDINAL_COLOR);
      label.textContent = dir;
      svg.appendChild(label);
    });
  }

  function addPath() {
    const path = document.createElementNS(svgns, "path");
    let pathD = "M";
    pathData.forEach((coords, index) => {
      const { x, y } = convertCoords(coords.az, coords.el);
      pathD += `${x},${y} `;
    });
    path.setAttribute("d", pathD);
    path.setAttribute("stroke", PATH_COLOR);
    path.setAttribute("stroke-width", "3");
    path.setAttribute("fill", "none");
    svg.appendChild(path);
  }

  function addStartHead() {
    if (pathData.length == 0) return;
    const firstPoint = convertCoords(pathData[0].az, pathData[0].el);

    // Create a filled circle of radius 10 at the start of the path
    const startHead = document.createElementNS(svgns, "circle");
    startHead.setAttribute("cx", firstPoint.x);
    startHead.setAttribute("cy", firstPoint.y);
    startHead.setAttribute("r", START_HEAD_SIZE);
    startHead.setAttribute("fill", PATH_COLOR);
    svg.appendChild(startHead);
  }

  function addArrowhead() {
    if (pathData.length < 2) return; // Need at least two points to define a direction

    const lastPoint = convertCoords(
      pathData[pathData.length - 1].az,
      pathData[pathData.length - 1].el
    );
    const secondLastPoint = convertCoords(
      pathData[pathData.length - 2].az,
      pathData[pathData.length - 2].el
    );

    // Calculate angle for the arrowhead
    const angle = Math.atan2(
      lastPoint.y - secondLastPoint.y,
      lastPoint.x - secondLastPoint.x
    );

    // Offset the arrowhead position to extend beyond the last point
    const tipOffset = 5; // Distance from the last point to the arrowhead tip
    const tipX = lastPoint.x + tipOffset * Math.cos(angle);
    const tipY = lastPoint.y + tipOffset * Math.sin(angle);

    // Coordinates for the base of the arrowhead (at the last point of the path)
    const baseX1 = lastPoint.x - ARROW_SIZE * Math.cos(angle - Math.PI / 6);
    const baseY1 = lastPoint.y - ARROW_SIZE * Math.sin(angle - Math.PI / 6);
    const baseX2 = lastPoint.x - ARROW_SIZE * Math.cos(angle + Math.PI / 6);
    const baseY2 = lastPoint.y - ARROW_SIZE * Math.sin(angle + Math.PI / 6);

    // Create a triangle (arrowhead)
    const arrowPath = document.createElementNS(svgns, "path");
    const arrowD = `M ${tipX} ${tipY} L ${baseX1} ${baseY1} L ${baseX2} ${baseY2} Z`;
    arrowPath.setAttribute("d", arrowD);
    arrowPath.setAttribute("fill", PATH_COLOR);
    svg.appendChild(arrowPath);
  }

  function addSatellite() {
    // Add current position of the satellite
    const currentPos = convertCoords(
      currentPosition.azimuth,
      currentPosition.elevation
    );
    const satellite = document.createElementNS(svgns, "circle");
    satellite.setAttribute("cx", currentPos.x);
    satellite.setAttribute("cy", currentPos.y);
    satellite.setAttribute("r", "10");
    satellite.setAttribute("fill", SATELLITE_COLOR);
    satellite.setAttribute("stroke", SATELLITE_COLOR);
    satellite.setAttribute("stroke-width", "3");
    svg.appendChild(satellite);

    const setter = function (azimuth, elevation) {
      elevation = Math.max(elevation, MIN_ELEVATION);
      const pos = convertCoords(azimuth, elevation);
      satellite.setAttribute("cx", pos.x);
      satellite.setAttribute("cy", pos.y);

      if (elevation < 0) {
        satellite.setAttribute("fill", "white");
        satellite.setAttribute("stroke", HIDDEN_SATELLITE_COLOR);
        satellite.setAttribute("stroke-dasharray", "3,2");
      } else {
        satellite.setAttribute("fill", SATELLITE_COLOR);
        satellite.setAttribute("stroke", SATELLITE_COLOR);
        satellite.removeAttribute("stroke-dasharray");
      }
    };

    return setter;
  }

  // Draw elements
  addIntercardinalDirections();
  addElevationCircles();
  addPath();
  const moveSatellite = addSatellite();
  addStartHead();
  addArrowhead();

  return { svg, moveSatellite };
}
