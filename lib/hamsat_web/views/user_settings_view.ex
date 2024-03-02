defmodule HamsatWeb.UserSettingsView do
  use HamsatWeb, :view

  import HamsatWeb.LayoutComponents

  defp curl_upcoming_alerts(key) do
    "curl -H 'Authorization: Bearer #{key}' #{url(~p"/api/alerts/upcoming")}"
  end
end
