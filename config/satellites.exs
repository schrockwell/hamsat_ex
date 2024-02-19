import Config

#
# SOURCES:
# https://www.amsat.org/two-way-satellites/
# https://www.amsat.org/linear-satellite-frequency-summary/
# https://www.amsat.org/tle/daily-bulletin.txt
#
satellites =
  [
    %{
      name: "AO-7",
      nasa_name: "AO-07",
      number: 7530,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear_non_inv,
          status: :problems,
          downlink: %{lower_mhz: 29.4000, upper_mhz: 29.5000},
          uplink: %{lower_mhz: 145.850, upper_mhz: 145.950}
        },
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 145.925, upper_mhz: 145.975},
          uplink: %{lower_mhz: 432.125, upper_mhz: 432.175}
        }
      ]
    },
    %{
      name: "AO-27",
      number: 22825,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 436.795, upper_mhz: 436.795},
          uplink: %{lower_mhz: 145.850, upper_mhz: 145.850}
        }
      ]
    },
    %{
      name: "AO-73",
      aliases: ["FUNcube-1"],
      number: 39444,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 145.950, upper_mhz: 145.970},
          uplink: %{lower_mhz: 435.130, upper_mhz: 435.150}
        }
      ]
    },
    %{
      name: "AO-91",
      aliaes: ["Fox-1B", "RadFxSat"],
      number: 43017,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 145.96, upper_mhz: 145.96},
          uplink: %{lower_mhz: 435.250, upper_mhz: 435.250}
        }
      ]
    },
    %{
      name: "AO-92",
      aliases: ["Fox-1D"],
      number: 43137,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 145.880, upper_mhz: 145.880},
          uplink: %{lower_mhz: 435.350, upper_mhz: 435.350}
        }
      ]
    },
    %{
      name: "BeliefSat-0",
      number: 58695,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 145.980, upper_mhz: 145.980},
          uplink: %{lower_mhz: 437.000, upper_mhz: 437.000}
        }
      ]
    },
    %{
      name: "CAS-4A",
      number: 42761,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 145.860, upper_mhz: 145.880},
          uplink: %{lower_mhz: 435.210, upper_mhz: 435.230}
        }
      ]
    },
    %{
      name: "CAS-4B",
      number: 42759,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 145.915, upper_mhz: 145.935},
          uplink: %{lower_mhz: 435.270, upper_mhz: 435.290}
        }
      ]
    },
    %{
      name: "FO-29",
      aliases: ["JAS-2"],
      number: 24278,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 435.800, upper_mhz: 435.900},
          uplink: %{lower_mhz: 145.900, upper_mhz: 146.000}
        }
      ]
    },
    %{
      name: "FO-99",
      number: 43937,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 435.880, upper_mhz: 435.910},
          uplink: %{lower_mhz: 145.900, upper_mhz: 145.930}
        }
      ]
    },
    %{
      name: "GREENCUBE",
      nasa_name: "IO-117",
      number: 53106,
      modulations: [:digital],
      transponders: [
        %{
          mode: :digital,
          status: :active,
          downlink: %{lower_mhz: 435.310, upper_mhz: 435.310},
          uplink: %{lower_mhz: 435.310, upper_mhz: 435.310}
        }
      ]
    },
    %{
      name: "ISS",
      number: 25544,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 437.8, upper_mhz: 437.8},
          uplink: %{lower_mhz: 145.990, upper_mhz: 145.990}
        }
      ]
    },
    %{
      name: "JO-97",
      number: 43803,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 145.855, upper_mhz: 145.875},
          uplink: %{lower_mhz: 435.100, upper_mhz: 435.120}
        }
      ]
    },
    %{
      name: "LEDSAT",
      number: 49069,
      modulations: [:digital],
      transponders: [
        %{
          mode: :digital,
          status: :active,
          downlink: %{lower_mhz: 435.190, upper_mhz: 435.190},
          uplink: %{lower_mhz: 435.310, upper_mhz: 435.310}
        }
      ]
    },
    %{
      name: "LilacSat-2",
      aliases: ["CAS-3H"],
      nasa_name: "LILACSAT-2",
      number: 40908,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 437.2, upper_mhz: 437.2},
          uplink: %{lower_mhz: 144.350, upper_mhz: 144.350}
        }
      ]
    },
    # %{name: "MO-112", number: 48868, modulations: [:fm]},
    %{
      name: "PO-101",
      aliases: ["Diwata-2"],
      number: 43678,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 145.9, upper_mhz: 145.9},
          uplink: %{lower_mhz: 437.500, upper_mhz: 437.500}
        }
      ]
    },
    %{
      name: "RS-44",
      number: 44909,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 435.610, upper_mhz: 435.670},
          uplink: %{lower_mhz: 145.935, upper_mhz: 145.995}
        }
      ]
    },
    %{
      name: "SO-50",
      aliases: ["SaudiSat-1C"],
      number: 27607,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 436.795, upper_mhz: 436.795},
          uplink: %{lower_mhz: 145.850, upper_mhz: 145.850}
        }
      ]
    },
    %{
      name: "SO-121",
      aliases: ["HADES-D"],
      number: 58567,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 436.663, upper_mhz: 436.663},
          uplink: %{lower_mhz: 145.875, upper_mhz: 145.875}
        }
      ]
    },
    %{
      name: "TO-108",
      number: 44881,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 145.915, upper_mhz: 145.935},
          uplink: %{lower_mhz: 435.270, upper_mhz: 435.290}
        }
      ]
    },
    %{
      name: "XW-2A",
      aliases: ["CAS-3A"],
      number: 40903,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 145.665, upper_mhz: 145.685},
          uplink: %{lower_mhz: 435.030, upper_mhz: 435.050}
        }
      ]
    },
    %{
      name: "XW-2C",
      aliases: ["CAS-3C"],
      number: 40906,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 145.795, upper_mhz: 145.815},
          uplink: %{lower_mhz: 435.150, upper_mhz: 435.170}
        }
      ]
    },
    %{
      name: "EO-88",
      aliases: ["Nayif-1"],
      number: 42017,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 145.960, upper_mhz: 145.990},
          uplink: %{lower_mhz: 435.015, upper_mhz: 435.045}
        }
      ]
    },
    %{
      name: "FO-118",
      aliases: ["CAS-5A"],
      number: 54684,
      modulations: [:linear, :fm],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 145.960, upper_mhz: 145.990},
          uplink: %{lower_mhz: 21.4275, upper_mhz: 21.4425}
        },
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 435.525, upper_mhz: 435.555},
          uplink: %{lower_mhz: 145.805, upper_mhz: 145.835}
        },
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 435.600, upper_mhz: 435.600},
          uplink: %{lower_mhz: 145.925, upper_mhz: 145.925}
        }
      ]
    },
    %{
      name: "HO-113",
      aliases: ["CAS-9", "XW-3"],
      number: 50466,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 435.165, upper_mhz: 435.195},
          uplink: %{lower_mhz: 145.855, upper_mhz: 145.885}
        }
      ]
    },
    %{
      name: "HO-119",
      number: 54816,
      modulations: [:linear],
      transponders: [
        %{
          mode: :linear,
          status: :active,
          downlink: %{lower_mhz: 435.165, upper_mhz: 435.195},
          uplink: %{lower_mhz: 145.855, upper_mhz: 145.885}
        }
      ]
    },
    %{
      name: "Tevel-2",
      number: 51069,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 436.400, upper_mhz: 436.400},
          uplink: %{lower_mhz: 145.970, upper_mhz: 145.970}
        }
      ]
    },
    %{
      name: "Tevel-3",
      number: 50988,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 436.400, upper_mhz: 436.400},
          uplink: %{lower_mhz: 145.970, upper_mhz: 145.970}
        }
      ]
    },
    %{
      name: "Tevel-4",
      number: 51063,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 436.400, upper_mhz: 436.400},
          uplink: %{lower_mhz: 145.970, upper_mhz: 145.970}
        }
      ]
    },
    %{
      name: "Tevel-5",
      number: 50998,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 436.400, upper_mhz: 436.400},
          uplink: %{lower_mhz: 145.970, upper_mhz: 145.970}
        }
      ]
    },
    %{
      name: "Tevel-6",
      number: 50999,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 436.400, upper_mhz: 436.400},
          uplink: %{lower_mhz: 145.970, upper_mhz: 145.970}
        }
      ]
    },
    %{
      name: "Tevel-7",
      number: 51062,
      modulations: [:fm],
      transponders: [
        %{
          mode: :fm,
          status: :active,
          downlink: %{lower_mhz: 436.400, upper_mhz: 436.400},
          uplink: %{lower_mhz: 145.970, upper_mhz: 145.970}
        }
      ]
    }
  ]
  |> Enum.map(&Map.put_new(&1, :slug, &1.name))

config :hamsat, :satellites, satellites
