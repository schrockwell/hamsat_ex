defmodule Hamsat.Alerts.Match do
  def amend_alert(alert, %{user: :guest} = _context) do
    alert
  end

  def amend_alert(alert, context) do
    match =
      %{}
      |> score_mode(alert, context.user)
      |> score_elevation(:dx_el, alert.activator_closest_position, context.user.prefer_dx_el)
      |> score_elevation(:my_el, alert.my_closest_position, context.user.prefer_my_el)
      |> score_total()

    %{alert | match: match}
  end

  defp score_mode(match, alert, user) do
    max_rank =
      user
      |> Map.take([:prefer_cw_mode, :prefer_ssb_mode, :prefer_data_mode, :prefer_fm_mode])
      |> Map.values()
      |> Enum.max()

    alert_rank =
      case alert.mode do
        "SSB" -> user.prefer_ssb_mode
        "CW" -> user.prefer_cw_mode
        "Data" -> user.prefer_data_mode
        "FM" -> user.prefer_fm_mode
        _ -> max_rank
      end

    Map.put(match, :mode, alert_rank / max_rank)
  end

  defp score_elevation(match, match_field, sat_position, preferred_el) do
    elevation_score =
      cond do
        # Nada
        sat_position == nil ->
          0.0

        # Below horizon
        sat_position.elevation_in_degrees < 0 ->
          0.0

        # Avoid dividing by zero - assume perfect match
        preferred_el == 0 ->
          1.0

        # Higher than preferred
        sat_position.elevation_in_degrees >= preferred_el ->
          1.0

        # In between
        true ->
          sat_position.elevation_in_degrees / preferred_el
          # :math.sin(sat_position.elevation_in_degrees / preferred_el * :math.pi() / 2)
      end

    Map.put(match, match_field, elevation_score)
  end

  defp score_total(match) do
    elevation_score = (sin_curve(match.dx_el) + sin_curve(match.my_el)) / 2
    mode_score = match.mode

    total_score = elevation_score * mode_score
    Map.put(match, :total, total_score)
  end

  # defp log10_curve(value) do
  #   :math.log10(value * 10)
  # end

  defp sin_curve(value) do
    :math.sin(value * :math.pi() / 2)
  end
end
