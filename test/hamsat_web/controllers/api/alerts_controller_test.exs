defmodule HamsatWeb.API.AlertsControllerTest do
  use HamsatWeb.ConnCase

  import Hamsat.AccountsFixtures

  alias Hamsat.Alerts
  alias Hamsat.Factory
  alias Hamsat.Passes
  alias Hamsat.Util

  @one_day [ending: Timex.shift(DateTime.utc_now(), hours: 24)]

  setup do
    %{}
    |> Factory.guest_context(:context)
    |> Factory.satellite(:ao_7, "AO-7")
  end

  describe "GET /api/alerts" do
    test "returns an empty list when there are no alerts", %{conn: conn} do
      conn = get(conn, ~p"/api/alerts")
      assert json_response(conn, 200) == %{"data" => []}
    end

    test "returns upcoming alerts", %{conn: conn, context: context, ao_7: ao_7} do
      alert = insert_alert(context, ao_7)

      conn = get(conn, ~p"/api/alerts")

      assert %{"data" => [%{"id" => id, "callsign" => "WW1X"}]} = json_response(conn, 200)
      assert id == alert.id
    end

    test "GET /api/alerts/upcoming returns the same payload", %{
      conn: conn,
      context: context,
      ao_7: ao_7
    } do
      insert_alert(context, ao_7)

      index_response = conn |> get(~p"/api/alerts") |> json_response(200)
      upcoming_response = conn |> get(~p"/api/alerts/upcoming") |> json_response(200)

      assert index_response == upcoming_response
    end
  end

  describe "GET /api/alerts/:id" do
    test "returns an alert", %{conn: conn, context: context, ao_7: ao_7} do
      alert = insert_alert(context, ao_7)

      conn = get(conn, ~p"/api/alerts/#{alert.id}")

      assert %{"data" => %{"id" => id, "satellite" => %{"number" => 7530}}} =
               json_response(conn, 200)

      assert id == alert.id
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/alerts/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404) == %{"errors" => ["Not Found"]}
    end

    test "returns 404 for a malformed id", %{conn: conn} do
      conn = get(conn, ~p"/api/alerts/not-a-uuid")
      assert json_response(conn, 404) == %{"errors" => ["Not Found"]}
    end
  end

  describe "POST /api/alerts" do
    setup %{context: context, ao_7: ao_7} do
      user = user_fixture()
      context = %{context | user: user}
      [pass | _] = Passes.list_passes(context, ao_7, @one_day)
      %{user: user, context: context, pass: pass}
    end

    test "creates an alert", %{conn: conn, user: user, ao_7: ao_7, pass: pass} do
      conn =
        conn
        |> authorize(user)
        |> post_json(~p"/api/alerts", alert_params(ao_7, pass))

      assert %{"data" => %{"id" => id, "callsign" => "WW1X"}} = json_response(conn, 201)
      assert [location] = get_resp_header(conn, "location")
      assert location =~ "/api/alerts/#{id}"

      alert = Hamsat.Repo.get!(Hamsat.Schemas.Alert, id)
      assert alert.user_id == user.id
      assert alert.satellite_id == ao_7.id
    end

    test "returns 401 without an API key", %{conn: conn, ao_7: ao_7, pass: pass} do
      conn = post_json(conn, ~p"/api/alerts", alert_params(ao_7, pass))
      assert json_response(conn, 401) == %{"errors" => ["Unauthorized"]}
    end

    test "returns 401 with an unknown API key", %{conn: conn, ao_7: ao_7, pass: pass} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{Ecto.UUID.generate()}")
        |> post_json(~p"/api/alerts", alert_params(ao_7, pass))

      assert json_response(conn, 401) == %{"errors" => ["Unauthorized"]}
    end

    test "returns 422 for validation errors", %{conn: conn, user: user, ao_7: ao_7, pass: pass} do
      params = %{alert_params(ao_7, pass) | callsign: ""}

      conn =
        conn
        |> authorize(user)
        |> post_json(~p"/api/alerts", params)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, &(&1 =~ "callsign"))
    end

    test "returns 422 when no pass matches max_at", %{
      conn: conn,
      user: user,
      ao_7: ao_7,
      pass: pass
    } do
      max_at =
        pass.info.max.datetime
        |> Util.erl_to_utc_datetime()
        |> DateTime.add(31 * 60, :second)

      params = %{alert_params(ao_7, pass) | max_at: DateTime.to_iso8601(max_at)}

      conn =
        conn
        |> authorize(user)
        |> post_json(~p"/api/alerts", params)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, &(&1 =~ "max_at"))
    end

    test "returns 422 for an unknown satellite", %{conn: conn, user: user, ao_7: ao_7, pass: pass} do
      for satellite_number <- [999_999_999, "not-a-number"] do
        params = %{alert_params(ao_7, pass) | satellite_number: satellite_number}

        conn =
          conn
          |> authorize(user)
          |> post_json(~p"/api/alerts", params)

        assert %{"errors" => errors} = json_response(conn, 422)
        assert Enum.any?(errors, &(&1 =~ "NORAD"))
      end
    end

    test "returns 422 for invalid grids", %{conn: conn, user: user, ao_7: ao_7, pass: pass} do
      # Too many entries -> rejected before the changeset; missing entirely ->
      # the changeset's grid_1 requirement, remapped to the grids key
      too_many = %{alert_params(ao_7, pass) | grids: ["FN31", "FN32", "FN33", "FN41", "FN42"]}
      missing = Map.delete(alert_params(ao_7, pass), :grids)

      for params <- [too_many, missing] do
        conn =
          conn
          |> authorize(user)
          |> post_json(~p"/api/alerts", params)

        assert %{"errors" => errors} = json_response(conn, 422)
        assert Enum.any?(errors, &(&1 =~ "grids"))
      end
    end

    test "returns 422 for a malformed max_at", %{conn: conn, user: user, ao_7: ao_7, pass: pass} do
      params = %{alert_params(ao_7, pass) | max_at: "yesterday-ish"}

      conn =
        conn
        |> authorize(user)
        |> post_json(~p"/api/alerts", params)

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, &(&1 =~ "max_at"))
    end
  end

  describe "PATCH /api/alerts/:id" do
    setup %{context: context, ao_7: ao_7} do
      user = user_fixture()
      %{user: user, alert: insert_alert(context, ao_7, user)}
    end

    test "updates only the provided fields", %{conn: conn, user: user, alert: alert} do
      conn =
        conn
        |> authorize(user)
        |> patch_json(~p"/api/alerts/#{alert.id}", %{callsign: "W1AW", comment: "updated"})

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == alert.id
      assert data["callsign"] == "W1AW"
      assert data["comment"] == "updated"
      assert data["grids"] == ["FN31"]

      updated = Hamsat.Repo.get!(Hamsat.Schemas.Alert, alert.id)
      assert updated.aos_at == alert.aos_at
      assert updated.los_at == alert.los_at
    end

    test "replaces the grids list", %{conn: conn, user: user, alert: alert} do
      conn =
        conn
        |> authorize(user)
        |> patch_json(~p"/api/alerts/#{alert.id}", %{grids: ["FN32", "FN42"]})

      assert %{"data" => %{"grids" => ["FN32", "FN42"]}} = json_response(conn, 200)
    end

    test "rejects immutable fields", %{conn: conn, user: user, alert: alert} do
      immutable = %{
        satellite_number: 39444,
        observer_lat: 40.0,
        observer_lon: -74.0,
        max_at: DateTime.to_iso8601(DateTime.utc_now())
      }

      for {field, value} <- immutable do
        conn =
          conn
          |> authorize(user)
          |> patch_json(~p"/api/alerts/#{alert.id}", %{field => value})

        assert json_response(conn, 422) == %{"errors" => ["#{field} cannot be changed"]}
      end
    end

    test "returns 401 without an API key", %{conn: conn, alert: alert} do
      conn = patch_json(conn, ~p"/api/alerts/#{alert.id}", %{callsign: "W1AW"})
      assert json_response(conn, 401) == %{"errors" => ["Unauthorized"]}
    end

    test "returns 403 for someone else's alert", %{conn: conn, alert: alert} do
      conn =
        conn
        |> authorize(user_fixture())
        |> patch_json(~p"/api/alerts/#{alert.id}", %{callsign: "W1AW"})

      assert json_response(conn, 403) == %{"errors" => ["Forbidden"]}
    end

    test "returns 404 for an unknown alert", %{conn: conn, user: user} do
      conn =
        conn
        |> authorize(user)
        |> patch_json(~p"/api/alerts/#{Ecto.UUID.generate()}", %{callsign: "W1AW"})

      assert json_response(conn, 404) == %{"errors" => ["Not Found"]}
    end

    test "returns 422 for validation errors", %{conn: conn, user: user, alert: alert} do
      conn =
        conn
        |> authorize(user)
        |> patch_json(~p"/api/alerts/#{alert.id}", %{callsign: "x"})

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Enum.any?(errors, &(&1 =~ "callsign"))
    end
  end

  describe "DELETE /api/alerts/:id" do
    setup %{context: context, ao_7: ao_7} do
      user = user_fixture()
      %{user: user, alert: insert_alert(context, ao_7, user)}
    end

    test "deletes the alert", %{conn: conn, user: user, alert: alert} do
      conn =
        conn
        |> authorize(user)
        |> delete(~p"/api/alerts/#{alert.id}")

      assert response(conn, 204)
      assert Hamsat.Repo.get(Hamsat.Schemas.Alert, alert.id) == nil
    end

    test "returns 401 without an API key", %{conn: conn, alert: alert} do
      conn = delete(conn, ~p"/api/alerts/#{alert.id}")
      assert json_response(conn, 401) == %{"errors" => ["Unauthorized"]}
    end

    test "returns 403 for someone else's alert", %{conn: conn, alert: alert} do
      conn =
        conn
        |> authorize(user_fixture())
        |> delete(~p"/api/alerts/#{alert.id}")

      assert json_response(conn, 403) == %{"errors" => ["Forbidden"]}
      refute Hamsat.Repo.get(Hamsat.Schemas.Alert, alert.id) == nil
    end

    test "returns 404 for an unknown alert", %{conn: conn, user: user} do
      conn =
        conn
        |> authorize(user)
        |> delete(~p"/api/alerts/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404) == %{"errors" => ["Not Found"]}
    end
  end

  defp authorize(conn, user) do
    put_req_header(conn, "authorization", "Bearer #{user.feed_key}")
  end

  defp post_json(conn, path, params) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(path, Jason.encode!(params))
  end

  defp patch_json(conn, path, params) do
    conn
    |> put_req_header("content-type", "application/json")
    |> patch(path, Jason.encode!(params))
  end

  defp alert_params(sat, pass) do
    max_at = Util.erl_to_utc_datetime(pass.info.max.datetime)

    %{
      satellite_number: sat.number,
      observer_lat: 41.5,
      observer_lon: -73.0,
      max_at: DateTime.to_iso8601(max_at),
      callsign: "WW1X",
      grids: ["FN31"],
      mhz_direction: "down"
    }
  end

  defp insert_alert(context, sat, user \\ nil) do
    context = %{context | user: user || user_fixture()}
    [pass | _] = Passes.list_passes(context, sat, @one_day)

    params = %{
      "callsign" => "WW1X",
      "grid_1" => "FN31",
      "satellite_id" => sat.id,
      "pass_hash" => pass.hash,
      "observer_lat" => 41.5,
      "observer_lon" => -73.0,
      "mhz_direction" => "down"
    }

    {:ok, alert} =
      Alerts.create_alert(context, Alerts.change_alert(context, sat, pass, params))

    alert
  end
end
