defmodule HamsatWeb.SatsLive.Index do
  use HamsatWeb, :live_view

  alias Hamsat.Satellites
  alias HamsatWeb.SatComponents

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Satellites")}
  end

  def handle_params(params, _url, socket) do
    query = to_string(params["q"])

    if query == "" do
      {:noreply, assign(socket, query: query, sats: Satellites.list_satellites_and_stats())}
    else
      {:noreply, assign(socket, query: query, sats: Satellites.search_satellites_and_stats(query))}
    end
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: ~p"/sats?q=#{query}")}
  end
end
