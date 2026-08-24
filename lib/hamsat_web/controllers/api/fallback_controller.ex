defmodule HamsatWeb.API.FallbackController do
  use HamsatWeb, :controller

  alias HamsatWeb.API.ErrorView

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(ErrorView)
    |> render("403.json")
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(ErrorView)
    |> render("404.json")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    unprocessable(conn, changeset_errors(changeset))
  end

  def call(conn, {:error, :satellite_not_found}) do
    unprocessable(conn, ["No satellite found with this NORAD ID"])
  end

  def call(conn, {:error, :invalid_grids}) do
    unprocessable(conn, ["grids must be a list of 1 to 4 grid squares"])
  end

  def call(conn, {:error, :invalid_observer}) do
    unprocessable(conn, ["observer_lat and observer_lon must be numbers"])
  end

  def call(conn, {:error, :invalid_max_at}) do
    unprocessable(conn, ["max_at must be an ISO 8601 datetime"])
  end

  def call(conn, {:error, {:immutable_params, fields}}) do
    unprocessable(conn, Enum.map(fields, &"#{&1} cannot be changed"))
  end

  def call(conn, {:error, :no_matching_pass}) do
    unprocessable(conn, ["No pass found within 30 minutes of max_at"])
  end

  # Flattens changeset errors into human-readable strings. The API accepts a
  # grids array, but AlertForm validates grid_1..grid_4 — report those as grids.
  defp changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&HamsatWeb.ErrorHelpers.translate_error/1)
    |> Enum.flat_map(fn
      {:base, messages} -> messages
      {field, messages} -> Enum.map(messages, &"#{rename_field(field)} #{&1}")
    end)
    |> Enum.uniq()
  end

  defp rename_field(field) when field in [:grid_1, :grid_2, :grid_3, :grid_4], do: :grids
  defp rename_field(field), do: field

  defp unprocessable(conn, errors) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ErrorView)
    |> render("422.json", errors: errors)
  end
end
