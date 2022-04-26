for attrs <- Hamsat.Satellites.known() do
  Hamsat.Satellites.upsert_satellite!(attrs.number, attrs)
end

Hamsat.Accounts.register_user(%{
  email: "foo@bar.com",
  password: "hello123",
  home_lat: 42,
  home_lon: -70
})
