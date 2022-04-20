for attrs <- Hamsat.Satellites.known() do
  Hamsat.Satellites.upsert_satellite!(attrs.number, attrs)
end
