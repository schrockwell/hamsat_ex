defmodule HamsatWeb.APISpec do
  @moduledoc """
  The OpenAPI 3.0 document for the Hamsat JSON API, served at /api/openapi.json
  and browsable at /api/docs.
  """

  def spec do
    %{
      openapi: "3.0.3",
      info: %{
        title: "Hamsat API",
        version: "1.0.0",
        description: """
        JSON API for hams.at activation alerts.

        Read endpoints are public. Authenticated requests use your API key \
        (found on the Settings page) as a bearer token, which also adapts \
        pass predictions to your station location. Creating an alert requires \
        authentication.
        """
      },
      servers: [%{url: "/"}],
      paths: paths(),
      components: %{
        securitySchemes: %{
          bearerAuth: %{
            type: "http",
            scheme: "bearer",
            description: "Your API key from the Settings page."
          }
        },
        schemas: schemas()
      }
    }
  end

  defp paths do
    %{
      "/api/alerts" => %{
        get: %{
          summary: "List upcoming alerts",
          tags: ["Alerts"],
          responses: %{
            "200" => %{
              description: "Upcoming alerts, soonest first",
              content: json_content("AlertList")
            }
          }
        },
        post: %{
          summary: "Create an alert",
          description: """
          Creates an activation alert for a satellite pass. The pass is \
          identified by the satellite, the observer coordinates, and the \
          approximate time of maximum elevation (`max_at`) — the server \
          matches the nearest computed pass within ±30 minutes.
          """,
          tags: ["Alerts"],
          security: [%{bearerAuth: []}],
          requestBody: %{
            required: true,
            content: json_content("AlertCreate")
          },
          responses: %{
            "201" => %{
              description: "Alert created",
              content: json_content("AlertResponse")
            },
            "401" => %{description: "Missing or invalid API key", content: json_content("Error")},
            "422" => %{description: "Validation failed", content: json_content("Error")}
          }
        }
      },
      "/api/alerts/upcoming" => %{
        get: %{
          summary: "List upcoming alerts (legacy)",
          description: "Legacy alias for `GET /api/alerts`.",
          tags: ["Alerts"],
          responses: %{
            "200" => %{
              description: "Upcoming alerts, soonest first",
              content: json_content("AlertList")
            }
          }
        }
      },
      "/api/alerts/{id}" => %{
        get: %{
          summary: "Get an alert",
          tags: ["Alerts"],
          parameters: [id_parameter()],
          responses: %{
            "200" => %{description: "The alert", content: json_content("AlertResponse")},
            "404" => %{description: "Alert not found", content: json_content("Error")}
          }
        },
        patch: %{
          summary: "Update an alert",
          description: """
          Updates an alert you own. All fields are optional — omitted fields \
          keep their current values. The pass identifies the alert, so \
          `satellite_number`, `observer_lat`, `observer_lon`, and `max_at` are \
          immutable; sending them is rejected. Also available as PUT.
          """,
          tags: ["Alerts"],
          security: [%{bearerAuth: []}],
          parameters: [id_parameter()],
          requestBody: %{
            required: true,
            content: json_content("AlertUpdate")
          },
          responses: %{
            "200" => %{description: "Alert updated", content: json_content("AlertResponse")},
            "401" => %{description: "Missing or invalid API key", content: json_content("Error")},
            "403" => %{description: "You do not own this alert", content: json_content("Error")},
            "404" => %{description: "Alert not found", content: json_content("Error")},
            "422" => %{description: "Validation failed", content: json_content("Error")}
          }
        },
        delete: %{
          summary: "Delete an alert",
          description: "Deletes an alert you own.",
          tags: ["Alerts"],
          security: [%{bearerAuth: []}],
          parameters: [id_parameter()],
          responses: %{
            "204" => %{description: "Alert deleted"},
            "401" => %{description: "Missing or invalid API key", content: json_content("Error")},
            "403" => %{description: "You do not own this alert", content: json_content("Error")},
            "404" => %{description: "Alert not found", content: json_content("Error")}
          }
        }
      }
    }
  end

  defp id_parameter do
    %{
      name: "id",
      in: "path",
      required: true,
      schema: %{type: "string", format: "uuid"}
    }
  end

  defp schemas do
    %{
      "Alert" => %{
        type: "object",
        properties: %{
          id: %{type: "string", format: "uuid"},
          callsign: %{type: "string"},
          comment: %{type: "string", nullable: true},
          grids: %{type: "array", items: %{type: "string"}},
          aos_at: %{type: "string", format: "date-time"},
          los_at: %{type: "string", format: "date-time"},
          mhz: %{type: "number", nullable: true},
          mhz_direction: %{type: "string", enum: ["up", "down"], nullable: true},
          mode: %{type: "string", nullable: true},
          satellite: %{
            type: "object",
            properties: %{
              name: %{type: "string"},
              number: %{type: "integer"}
            }
          },
          url: %{type: "string"},
          match_percent: %{
            type: "integer",
            nullable: true,
            description: "How well this alert matches your station, when authenticated"
          },
          max_elevation: %{type: "number", nullable: true},
          is_workable: %{type: "boolean", nullable: true},
          workable_start_at: %{type: "string", format: "date-time", nullable: true},
          workable_end_at: %{type: "string", format: "date-time", nullable: true},
          likes: %{type: "integer", nullable: true}
        }
      },
      "AlertCreate" => %{
        type: "object",
        required: [
          "satellite_number",
          "observer_lat",
          "observer_lon",
          "max_at",
          "callsign",
          "grids"
        ],
        properties: alert_input_properties()
      },
      "AlertUpdate" => %{
        type: "object",
        description: "All fields are optional — omitted fields keep their current values.",
        properties:
          Map.take(alert_input_properties(), [
            :callsign,
            :grids,
            :mhz,
            :mhz_direction,
            :mode,
            :comment,
            :chat_enabled
          ])
      },
      "AlertList" => %{
        type: "object",
        properties: %{data: %{type: "array", items: ref("Alert")}}
      },
      "AlertResponse" => %{
        type: "object",
        properties: %{data: ref("Alert")}
      },
      "Error" => %{
        type: "object",
        properties: %{
          errors: %{
            type: "array",
            items: %{type: "string"},
            description: "Human-readable error messages"
          }
        }
      }
    }
  end

  defp alert_input_properties do
    %{
      satellite_number: %{
        type: "integer",
        description: "NORAD catalog number of the satellite",
        example: 7530
      },
      observer_lat: %{type: "number", minimum: -90, maximum: 90},
      observer_lon: %{type: "number", minimum: -180, maximum: 180},
      max_at: %{
        type: "string",
        format: "date-time",
        description: "Approximate time of the pass's maximum elevation (±30 minutes)"
      },
      callsign: %{type: "string", minLength: 3},
      grids: %{
        type: "array",
        items: %{type: "string"},
        minItems: 1,
        maxItems: 4,
        description: "Maidenhead grid squares (4 or 6 characters) activated during the pass",
        example: ["FN31"]
      },
      mhz: %{
        type: "number",
        nullable: true,
        description: """
        Frequency in MHz. Optional; when the satellite has a single fixed \
        frequency for the chosen direction and mode, it is set automatically.\
        """
      },
      mhz_direction: %{
        type: "string",
        enum: ["up", "down"],
        default: "down",
        description: "Whether `mhz` refers to the uplink or downlink. Optional; defaults to \"down\"."
      },
      mode: %{
        type: "string",
        enum: ["SSB", "CW", "Data", "FM"],
        nullable: true,
        description: """
        Operating mode. Optional. Valid values depend on the satellite's \
        modulations: linear satellites accept SSB, CW, and Data; FM satellites \
        accept FM; digital satellites accept Data. An omitted or unsupported \
        value falls back to the satellite's default mode.\
        """
      },
      comment: %{type: "string", maxLength: 50, nullable: true},
      chat_enabled: %{
        type: "boolean",
        nullable: true,
        description: "Enable the on-site chat for this activation. Optional; defaults to true."
      }
    }
  end

  defp ref(name), do: %{"$ref": "#/components/schemas/#{name}"}

  defp json_content(schema_name) do
    %{"application/json" => %{schema: ref(schema_name)}}
  end
end
