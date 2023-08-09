defmodule TelemetryUI.Theme do
  @moduledoc """
  Customize the UI of the web view.

  - `primary_color`: *Example: #ff0000*, Used for the title and first color on the charts
  - `title`: *Example: "My metrics"*, Used for the HTML page title and the title in the header.
  - `description`: *Example: "HTTP, GraphQL and Database metrics"*, Used for the HTML description tag.
  - `logo`: SVG logo in string used for the favicon and header.
  - `scale`: List of hex colors used in the charts.
  - `share_key`: 16 characters string used to hash the shared page.
  - `share_path`: Path in string starting by a `/` used to generate the shared page. It’s difference from the metrics page since it does not require authentication.
  - `frame_options`: *Example: [{:last_30_minutes, 30, :minute}, {:last_2_hours, 120, :minute}]*, Used to generate the time frame in the header.
  """

  @logo """
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" class="bi bi-symmetry-vertical" viewBox="0 0 16 16">
      <path d="M7 2.5a.5.5 0 0 0-.939-.24l-6 11A.5.5 0 0 0 .5 14h6a.5.5 0 0 0 .5-.5v-11zm2.376-.484a.5.5 0 0 1 .563.245l6 11A.5.5 0 0 1 15.5 14h-6a.5.5 0 0 1-.5-.5v-11a.5.5 0 0 1 .376-.484zM10 4.46V13h4.658L10 4.46z"/>
    </svg>
  """
  @color_palette ~w(
      #3F84E5
      #7EB26D
      #EAB839
      #6ED0E0
      #EF843C
      #E24D42
      #1F78C1
      #BA43A9
      #705DA0
      #508642
      #CCA300
      #447EBC
      #C15C17
      #890F02
      #0A437C
      #6D1F62
      #584477
      #B7DBAB
      #F4D598
      #70DBED
      #F9BA8F
      #F29191
      #82B5D8
      #E5A8E2
      #AEA2E0
      #629E51
      #E5AC0E
      #64B0C8
      #E0752D
      #BF1B00
      #0A50A1
      #962D82
      #614D93
      #9AC48A
      #F2C96D
      #65C5DB
      #F9934E
      #EA6460
      #5195CE
      #D683CE
      #806EB7
      #3F6833
      #967302
      #2F575E
      #99440A
      #58140C
      #052B51
      #511749
      #3F2B5B
      #E0F9D7
      #FCEACA
      #CFFAFF
      #F9E2D2
      #FCE2DE
      #BADFF4
      #F9D9F9
      #DEDAF7
    )

  defstruct header_color: hd(@color_palette),
            primary_color: hd(@color_palette),
            title: "/metrics",
            description: "Metrics",
            logo: @logo,
            scale: @color_palette,
            share_key: nil,
            share_path: nil,
            frame_options: [
              {:last_30_minutes, 30, :minute},
              {:last_2_hours, 120, :minute},
              {:last_1_day, 1, :day},
              {:last_7_days, 7, :day},
              {:last_1_month, 1, :month},
              {:custom, 0, nil}
            ]
end
