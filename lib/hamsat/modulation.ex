defmodule Hamsat.Modulation do
  @modulations %{
    digital: %{
      alert_options: ["Data"],
      css_class: "bg-fuchsia-100 text-fuchsia-600",
      name: "Digital Modulation",
      short_name: "Dig"
    },
    fm: %{
      alert_options: ["FM"],
      css_class: "bg-amber-100 text-amber-600",
      name: "FM Modulation",
      short_name: "FM"
    },
    linear: %{
      alert_options: ["SSB", "CW", "Data"],
      css_class: "bg-sky-100 text-sky-600",
      name: "Linear (SSB/CW) Modulation",
      short_name: "Lin"
    }
  }

  def sat_values, do: Map.keys(@modulations)

  def list_by_alert_option(alert_option) do
    @modulations
    |> Map.keys()
    |> Enum.filter(fn modulation ->
      alert_option in @modulations[modulation].alert_options
    end)
  end

  def alert_options(modulations) do
    Enum.flat_map(modulations, fn mode -> @modulations[mode].alert_options end)
  end

  def name(modulation) do
    @modulations[modulation].name
  end

  def short_name(modulation) do
    @modulations[modulation].short_name
  end

  def css_class(modulation) do
    @modulations[modulation].css_class
  end
end
