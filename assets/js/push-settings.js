// Push-reminder toggle on the account settings page.
//
// Enabling asks for notification permission, subscribes this browser via the
// Push API, and saves both the preference and the subscription server-side.
// Disabling just turns the preference off (subscriptions are kept but unused).

function urlBase64ToUint8Array(base64String) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const rawData = atob(base64);
  return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)));
}

async function subscribe(vapidPublicKey) {
  const registration = await navigator.serviceWorker.register("/sw.js");
  await navigator.serviceWorker.ready;

  return registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
  });
}

async function save(enabled, subscription) {
  const csrfToken = document
    .querySelector("meta[name='csrf-token']")
    .getAttribute("content");

  const response = await fetch("/users/settings/push", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-csrf-token": csrfToken,
    },
    body: JSON.stringify({
      enabled,
      subscription: subscription ? subscription.toJSON() : null,
    }),
  });

  if (!response.ok) throw new Error(`Save failed (${response.status})`);
}

export function initPushSettings() {
  const checkbox = document.getElementById("push-reminders-toggle");
  if (!checkbox) return;

  const status = document.getElementById("push-reminders-status");
  const setStatus = (text, isError) => {
    if (!status) return;
    status.textContent = text;
    status.classList.toggle("text-red-500", !!isError);
  };

  if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
    checkbox.disabled = true;
    setStatus("Push notifications are not supported by this browser.", true);
    return;
  }

  const testButton = document.getElementById("push-test-button");
  if (testButton) {
    testButton.addEventListener("click", async () => {
      testButton.disabled = true;
      setStatus("Sending test notification…");

      try {
        const csrfToken = document
          .querySelector("meta[name='csrf-token']")
          .getAttribute("content");

        const response = await fetch("/users/settings/push/test", {
          method: "POST",
          headers: { "x-csrf-token": csrfToken },
        });
        const result = await response.json().catch(() => ({}));

        if (response.ok) {
          setStatus("Test notification sent.");
        } else if (result.error === "no_subscriptions") {
          setStatus("No browsers are subscribed yet — enable the toggle first.", true);
        } else {
          setStatus("Could not deliver the test notification.", true);
        }
      } catch (error) {
        console.error("Test notification error", error);
        setStatus("Something went wrong — please try again.", true);
      } finally {
        testButton.disabled = false;
      }
    });
  }

  checkbox.addEventListener("change", async () => {
    checkbox.disabled = true;

    try {
      if (checkbox.checked) {
        const permission = await Notification.requestPermission();
        if (permission !== "granted") {
          checkbox.checked = false;
          setStatus("Notification permission was denied.", true);
          return;
        }

        const subscription = await subscribe(checkbox.dataset.vapidPublicKey);
        await save(true, subscription);
        setStatus("Enabled for this browser.");
      } else {
        await save(false, null);
        setStatus("Disabled.");
      }
    } catch (error) {
      console.error("Push settings error", error);
      checkbox.checked = !checkbox.checked;
      setStatus("Something went wrong — please try again.", true);
    } finally {
      checkbox.disabled = false;
    }
  });
}
