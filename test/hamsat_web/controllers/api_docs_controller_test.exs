defmodule HamsatWeb.APIDocsControllerTest do
  use HamsatWeb.ConnCase

  test "GET /api/docs renders the API reference page", %{conn: conn} do
    conn = get(conn, ~p"/api/docs")
    assert html_response(conn, 200) =~ "api-reference"
  end

  test "GET /api/openapi.json returns the OpenAPI spec", %{conn: conn} do
    conn = get(conn, ~p"/api/openapi.json")
    spec = json_response(conn, 200)

    assert spec["openapi"] =~ ~r/^3\./
    assert Map.has_key?(spec["paths"], "/api/alerts")
    assert Map.has_key?(spec["paths"], "/api/alerts/{id}")
    assert Map.has_key?(spec["paths"], "/api/alerts/upcoming")
  end
end
