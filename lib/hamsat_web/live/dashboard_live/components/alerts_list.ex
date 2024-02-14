defmodule HamsatWeb.DashboardLive.Components.AlertsList do
  use HamsatWeb, :live_component

  alias Hamsat.Schemas.Alert
  alias HamsatWeb.DashboardLive.Components.AlertItem

  attr :alerts, :list, required: true
  attr :context, Hamsat.Context, required: true
  attr :id, :string, required: true
  attr :mine?, :boolean, default: false
  attr :now, DateTime, required: true

  slot :empty
  slot :inner_block

  def component(assigns) do
    ~H"""
    <.live_component
      module={__MODULE__}
      alerts={@alerts}
      context={@context}
      id={@id}
      mine?={@mine?}
      now={@now}
      empty={@empty}
      inner_block={@inner_block}
    />
    """
  end
end
