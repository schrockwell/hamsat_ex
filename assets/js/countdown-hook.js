// Client-side clocks. Every countdown, "in 1:44", "sets in 3:05", "Chat
// closes in 12m", etc. is rendered by the browser from timestamps the server
// put in data attributes, so the server never has to re-render a page just
// because a second passed. The Elixir side of this is
// HamsatWeb.CountdownComponents, and the formatting here must match it.
//
// All hooks on the page share one interval, aligned to the wall-clock second.

const active = new Set();
let timer = null;

function schedule(hook) {
  active.add(hook);
  if (!timer) {
    tick();
  }
}

function unschedule(hook) {
  active.delete(hook);
  if (active.size === 0 && timer) {
    clearTimeout(timer);
    timer = null;
  }
}

function tick() {
  active.forEach((hook) => hook.render());
  timer = setTimeout(tick, 1000 - (Date.now() % 1000));
}

function pad(n) {
  return n < 10 ? "0" + n : String(n);
}

function plural(n, unit) {
  return `${n} ${unit}${n === 1 ? "" : "s"}`;
}

// "H:MM" / "Dd H:MM", never negative
function countdown(seconds) {
  seconds = Math.max(seconds, 0);
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return days > 0
    ? `${days}d ${hours}:${pad(minutes)}`
    : `${hours}:${pad(minutes)}`;
}

// Mirrors HamsatWeb.ViewHelpers.hms/2
function hms(seconds, coarse) {
  const sign = seconds < 0 ? "-" : "";
  seconds = Math.abs(seconds);
  const days = Math.floor(seconds / 86400);
  seconds -= days * 86400;
  const hours = Math.floor(seconds / 3600);
  seconds -= hours * 3600;
  const minutes = Math.floor(seconds / 60);
  seconds -= minutes * 60;

  if (days === 0 && hours === 0) {
    return `${sign}${minutes}:${pad(seconds)}`;
  } else if (days === 0) {
    return coarse
      ? `${sign}${hours}:${pad(minutes)}h`
      : `${sign}${hours}:${pad(minutes)}:${pad(seconds)}`;
  } else {
    return coarse
      ? `${sign}${days}d ${hours}:${pad(minutes)}h`
      : `${sign}${days}d ${hours}:${pad(minutes)}:${pad(seconds)}`;
  }
}

// "just now" / "5 minutes ago" / "2 hours ago" / "3 days ago"
function ago(seconds) {
  seconds = Math.max(-seconds, 0);
  if (seconds < 60) return "just now";
  if (seconds < 3600) return `${plural(Math.floor(seconds / 60), "minute")} ago`;
  if (seconds < 86400) return `${plural(Math.floor(seconds / 3600), "hour")} ago`;
  return `${plural(Math.floor(seconds / 86400), "day")} ago`;
}

// Coarse "2d" / "5h" / "12m", never below 1m
function closes(seconds) {
  const minutes = Math.max(Math.ceil(seconds / 60), 1);
  if (minutes > 24 * 60) return `${Math.ceil(minutes / (24 * 60))}d`;
  if (minutes > 60) return `${Math.ceil(minutes / 60)}h`;
  return `${minutes}m`;
}

function format(style, seconds) {
  switch (style) {
    case "countdown":
      return countdown(seconds);
    case "coarse":
      return hms(seconds, true);
    case "hms":
      return hms(seconds, false);
    case "ago":
      return ago(seconds);
    case "closes":
      return closes(seconds);
    default:
      return String(seconds);
  }
}

function currentSegment(segments, now) {
  return (
    segments.find((s) => s.until == null || Date.parse(s.until) > now) ||
    segments[segments.length - 1]
  );
}

function segmentText(segment, now) {
  if (!segment) return "";
  if (segment.template == null) return segment.text || "";
  const seconds = Math.trunc((Date.parse(segment.to) - now) / 1000);
  return segment.template.replace("%s", format(segment.style, seconds));
}

export const Countdown = {
  mounted() {
    this.render();
    schedule(this);
  },

  updated() {
    // The server may have merged stale attributes back onto the element
    this.render();
  },

  destroyed() {
    unschedule(this);
  },

  render() {
    let segments;
    try {
      segments = JSON.parse(this.el.dataset.segments);
    } catch (_e) {
      return;
    }

    const text = segmentText(currentSegment(segments, Date.now()), Date.now());

    if (this.el.textContent !== text) {
      this.el.textContent = text;
    }
    this.el.classList.toggle("hidden", text === "");
  },
};

// Slides an absolutely-positioned element from left: 0% at data-start-at to
// left: 100% at data-end-at
export const ProgressCursor = {
  mounted() {
    this.render();
    schedule(this);
  },

  updated() {
    this.render();
  },

  destroyed() {
    unschedule(this);
  },

  render() {
    const start = Date.parse(this.el.dataset.startAt);
    const end = Date.parse(this.el.dataset.endAt);
    const progress = Math.min(Math.max((Date.now() - start) / (end - start), 0), 1);
    this.el.style.left = `${progress * 100}%`;
  },
};
