defmodule HamsatWeb.CountdownComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]

  alias HamsatWeb.CountdownComponents

  @now ~U[2026-09-02 12:00:00Z]

  defp shift(seconds), do: DateTime.add(@now, seconds)

  describe "format/2" do
    test ":countdown" do
      assert CountdownComponents.format(:countdown, 0) == "0:00"
      assert CountdownComponents.format(:countdown, -30) == "0:00"
      assert CountdownComponents.format(:countdown, 59) == "0:00"
      assert CountdownComponents.format(:countdown, 6240) == "1:44"
      assert CountdownComponents.format(:countdown, 86_400 + 3600 + 300) == "1d 1:05"
    end

    test ":coarse and :hms match ViewHelpers.hms/2" do
      for seconds <- [5, 65, 3661, 90_061, -65] do
        assert CountdownComponents.format(:coarse, seconds) == HamsatWeb.ViewHelpers.hms(seconds, coarse?: true)
        assert CountdownComponents.format(:hms, seconds) == HamsatWeb.ViewHelpers.hms(seconds)
      end
    end

    test ":ago" do
      assert CountdownComponents.format(:ago, 0) == "just now"
      assert CountdownComponents.format(:ago, -59) == "just now"
      assert CountdownComponents.format(:ago, -60) == "1 minute ago"
      assert CountdownComponents.format(:ago, -125) == "2 minutes ago"
      assert CountdownComponents.format(:ago, -3600) == "1 hour ago"
      assert CountdownComponents.format(:ago, -7200) == "2 hours ago"
      assert CountdownComponents.format(:ago, -86_400 * 3) == "3 days ago"
      # A future timestamp never reads as negative time
      assert CountdownComponents.format(:ago, 30) == "just now"
    end

    test ":closes" do
      assert CountdownComponents.format(:closes, 0) == "1m"
      assert CountdownComponents.format(:closes, 61) == "2m"
      assert CountdownComponents.format(:closes, 3600) == "60m"
      assert CountdownComponents.format(:closes, 3601) == "2h"
      assert CountdownComponents.format(:closes, 86_400) == "24h"
      assert CountdownComponents.format(:closes, 86_401) == "2d"
    end
  end

  describe "countdown_text/2" do
    test "picks the first segment that has not ended" do
      segments = [
        %{until: shift(60), text: "before"},
        %{until: shift(120), text: "during"},
        %{until: nil, text: "after"}
      ]

      assert CountdownComponents.countdown_text(segments, @now) == "before"
      assert CountdownComponents.countdown_text(segments, shift(60)) == "during"
      assert CountdownComponents.countdown_text(segments, shift(119)) == "during"
      assert CountdownComponents.countdown_text(segments, shift(120)) == "after"
      assert CountdownComponents.countdown_text(segments, shift(9999)) == "after"
    end

    test "fills a template with the duration to the segment's target" do
      aos = shift(6240)
      los = shift(6240 + 600)

      segments = [
        %{until: aos, template: "rises in %s", to: aos, style: :hms},
        %{until: los, template: "sets in %s", to: los, style: :hms},
        %{until: nil, template: "%s", to: los, style: :ago}
      ]

      assert CountdownComponents.countdown_text(segments, @now) == "rises in 1:44:00"
      assert CountdownComponents.countdown_text(segments, shift(6240 + 5)) == "sets in 9:55"
      assert CountdownComponents.countdown_text(segments, shift(6240 + 600 + 150)) == "2 minutes ago"
    end

    test "falls back to the last segment when every segment has ended" do
      segments = [%{until: shift(-10), text: "only"}]
      assert CountdownComponents.countdown_text(segments, @now) == "only"
    end

    test "truncates sub-second differences toward zero like the browser" do
      to = DateTime.add(@now, 1500, :millisecond)
      segments = [%{until: nil, template: "%s", to: to, style: :hms}]
      assert CountdownComponents.countdown_text(segments, @now) == "0:01"
    end
  end

  describe "countdown/1" do
    test "renders an ignored span with the segments and initial text" do
      # Mid-minute, so the rendered text is stable however long the render takes
      aos = DateTime.add(DateTime.utc_now(), 3630)
      assigns = %{aos: aos}

      html =
        rendered_to_string(~H"""
        <CountdownComponents.countdown
          id="test"
          class="text-sm"
          segments={[%{until: nil, template: "in %s", to: @aos, style: :countdown}]}
        />
        """)

      assert html =~ ~s(id="test")
      assert html =~ ~s(phx-hook="Countdown")
      assert html =~ ~s(phx-update="ignore")
      assert html =~ ~s(class="text-sm")
      assert html =~ "in 1:00"
      assert html =~ "&quot;style&quot;:&quot;countdown&quot;"
      assert html =~ "&quot;until&quot;:null"
    end

    test "hides the span when the current text is empty" do
      later = DateTime.add(DateTime.utc_now(), 3600)
      assigns = %{later: later}

      html =
        rendered_to_string(~H"""
        <CountdownComponents.countdown id="test" segments={[%{until: @later, text: ""}, %{until: nil, text: "Now"}]} />
        """)

      assert html =~ ~s(class="hidden")
    end
  end
end
