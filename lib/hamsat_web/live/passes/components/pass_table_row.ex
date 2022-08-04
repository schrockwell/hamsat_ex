defmodule HamsatWeb.Passes.Components.PassTableRow do
  use HamsatWeb, :love_component

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass
  alias HamsatWeb.SatComponents

  prop :context
  prop :id
  prop :now
  prop :pass

  defp pass_table_row_class(pass, now) do
    case Pass.progression(pass, now) do
      :upcoming -> ""
      :in_progress -> "bg-emerald-100 text-emerald-700 font-semibold"
      :passed -> "text-gray-400"
    end
  end
end
