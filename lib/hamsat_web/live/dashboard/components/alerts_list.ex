defmodule HamsatWeb.Dashboard.Components.AlertsList do
  use HamsatWeb, :love_component

  alias HamsatWeb.Dashboard.Components.AlertItem

  prop :alerts
  prop :context
  prop :id
  prop :mine?, default: false
  prop :now

  # Slots
  prop :empty
  prop :inner_block
end
