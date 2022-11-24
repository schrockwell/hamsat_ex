defmodule Hamsat.Modulation do
  @modulations %{
    digital: %{
      alert_options: ["Data"],
      css_class: "bg-fuchsia-100 text-fuchsia-600",
      fixed_downlink?: true,
      name: "Digital Modulation",
      short_name: "Dig"
    },
    fm: %{
      alert_options: ["FM"],
      css_class: "bg-amber-100 text-amber-600",
      fixed_downlink?: true,
      name: "FM Modulation",
      short_name: "FM"
    },
    linear: %{
      alert_options: ["SSB", "CW", "Data"],
      css_class: "bg-sky-100 text-sky-600",
      fixed_downlink?: false,
      name: "Linear (SSB/CW) Modulation",
      short_name: "Lin"
    }
  }

  def sat_values, do: Map.keys(@modulations)

  def alert_options(%{modulation: modulation} = _sat) do
    @modulations[modulation].alert_options
  end

  def name(%{modulation: modulation} = _sat) do
    @modulations[modulation].name
  end

  def short_name(%{modulation: modulation} = _sat) do
    @modulations[modulation].short_name
  end

  def css_class(%{modulation: modulation} = _sat) do
    @modulations[modulation].css_class
  end

  def fixed_downlink?(%{modulation: modulation} = _sat) do
    @modulations[modulation].fixed_downlink?
  end
end
