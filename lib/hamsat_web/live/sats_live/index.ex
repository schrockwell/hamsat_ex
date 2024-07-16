defmodule HamsatWeb.SatsLive.Index do
  use HamsatWeb, :live_view

  import HamsatWeb.SatComponents

  alias Hamsat.Satellites

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Satellites", all_sats: Satellites.list_satellites_and_stats())}
  end

  def handle_params(params, _url, socket) do
    query = to_string(params["q"])

    if query == "" do
      {:noreply, assign(socket, query: query, sats: socket.assigns.all_sats)}
    else
      {:noreply, assign(socket, query: query, sats: filter_sats(socket.assigns.all_sats, query))}
    end
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: ~p"/sats?q=#{query}")}
  end

  defp filter_sats(sats, query) do
    Enum.filter(sats, fn sat ->
      Enum.any?([sat.name | sat.aliases], fn name ->
        String.contains?(String.downcase(name), String.downcase(query))
      end)
    end)
  end

  defp sat_names(sat) do
    if sat.aliases == [] do
      sat.name
    else
      "#{sat.name} (#{Enum.join(sat.aliases, "/")})"
    end
  end
end
