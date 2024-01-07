defmodule HamsatWeb.FeedController do
  use HamsatWeb, :controller

  import HamsatWeb.ViewHelpers

  alias Atomex.Feed
  alias Atomex.Entry

  alias Hamsat.Accounts
  alias Hamsat.Alerts
  alias Hamsat.Context

  def upcoming_alerts(conn, params) do
    context = get_context(params)
    alerts = Alerts.list_alerts(context, [date: :upcoming, limit: 100], plain: true)

    updated_at =
      alerts
      |> Enum.map(& &1.updated_at)
      |> Enum.sort({:desc, DateTime})
      |> case do
        [] -> DateTime.utc_now()
        [h | _] -> h
      end

    body =
      Feed.new(url(~p"/"), updated_at, "Hams.at Activations")
      |> Feed.author("Rockwell Schrock WW1X", email: "hamsat@schrock.me")
      |> Feed.link(url(~p"/feeds/upcoming_alerts"), rel: "self")
      |> Feed.entries(Enum.map(alerts, &alert_entry(context, &1)))
      |> Feed.build()
      |> Atomex.generate_document()

    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, body)
  end

  defp alert_entry(context, alert) do
    title =
      "[#{date(context, alert.aos_at)}] #{alert.callsign} on #{alert.sat.name} from #{alert.grids |> Enum.join("/")}"

    content = """
    <ul>
      <li>Start time: #{time(context, alert.aos_at)} (#{timezone_name(context.timezone)})</li>
      <li>End time: #{time(context, alert.los_at)} (#{timezone_name(context.timezone)})</li>
      <li>Frequency: #{alert.mhz} MHz #{alert.mhz_direction}link</li>
      <li>Mode: #{alert.mode}</li>
      <li>Comment: #{alert.comment || "(none)"}</li>
    </ul>
    """

    Entry.new(url(~p"/alerts/#{alert.id}"), alert.updated_at, title)
    |> Entry.link(url(~p"/alerts/#{alert.id}"), rel: "alternate")
    |> Entry.content({:cdata, content}, type: "html")
    |> Entry.build()
  end

  defp get_context(%{"feed_key" => feed_key}) when is_binary(feed_key) do
    if user = Accounts.get_user_by_feed_key(feed_key) do
      Context.from_user(user)
    else
      %Context{}
    end
  end

  defp get_context(_), do: %Context{}
end
