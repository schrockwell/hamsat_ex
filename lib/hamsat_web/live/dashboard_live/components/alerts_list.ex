defmodule HamsatWeb.DashboardLive.Components.AlertsList do
  use HamsatWeb, :live_component

  alias HamsatWeb.DashboardLive.Components.AlertItem

  prop :alerts
  prop :context
  prop :mine?, default: false
  prop :now

  LiveAssign.LiveComponent.slot(:empty)
  LiveAssign.LiveComponent.slot(:inner_block)
end
