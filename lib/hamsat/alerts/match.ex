defmodule Hamsat.Alerts.Match do
  # Integer points per category; the three categories sum to 100
  @el_max_points 25
  @mode_max_points 50

  def el_max_points, do: @el_max_points
  def mode_max_points, do: @mode_max_points

  def amend_alert(alert, %{user: :guest} = _context) do
    alert
  end

  def amend_alert(alert, context) do
    my_el = elevation_points(alert.my_closest_position, context.user.prefer_my_el)
    dx_el = elevation_points(alert.activator_closest_position, context.user.prefer_dx_el)
    mode = mode_points(alert, context.user)

    match = %{
      my_el: my_el,
      dx_el: dx_el,
      mode: mode,
      total: (my_el + dx_el + mode) / 100
    }

    %{alert | match: match}
  end

  defp mode_points(alert, user) do
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

    mode_rank = if max_rank == 0, do: 0.0, else: alert_rank / max_rank
    round(mode_rank * @mode_max_points)
  end

  defp elevation_points(sat_position, preferred_el) do
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
      end

    round(sin_curve(elevation_score) * @el_max_points)
  end

  defp sin_curve(value) do
    :math.sin(value * :math.pi() / 2)
  end
end
