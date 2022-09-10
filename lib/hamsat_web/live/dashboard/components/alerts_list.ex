defmodule HamsatWeb.Dashboard.Components.AlertsList do
  use HamsatWeb, :live_component

  alias HamsatWeb.Dashboard.Components.AlertItem

  prop :alerts
  prop :context
  prop :mine?, default: false
  prop :now

  slot :empty
  slot :inner_block
end
