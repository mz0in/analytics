defmodule PlausibleWeb.Live.Components.ComboBoxTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias PlausibleWeb.Live.Components.ComboBox

  @ul "ul#dropdown-test-component[x-show=isOpen][x-ref=suggestions]"

  describe "static rendering" do
    test "renders suggestions" do
      assert doc = render_sample_component(new_options(10))

      assert element_exists?(
               doc,
               ~s/input#test-component[name="display-test-component"][phx-change="search"]/
             )

      assert element_exists?(doc, @ul)

      for i <- 1..10 do
        assert element_exists?(doc, suggestion_li(i))
      end
    end

    test "renders up to 15 suggestions by default" do
      assert doc = render_sample_component(new_options(20))

      assert element_exists?(doc, suggestion_li(14))
      assert element_exists?(doc, suggestion_li(15))

      refute element_exists?(doc, suggestion_li(16))
      refute element_exists?(doc, suggestion_li(17))

      assert Floki.text(doc) =~ "Max results reached"
    end

    test "renders up to n suggestions if provided" do
      assert doc = render_sample_component(new_options(20), suggestions_limit: 10)

      assert element_exists?(doc, suggestion_li(9))
      assert element_exists?(doc, suggestion_li(10))

      refute element_exists?(doc, suggestion_li(11))
      refute element_exists?(doc, suggestion_li(12))
    end

    test "Alpine.js: renders attrs focusing suggestion elements" do
      assert doc = render_sample_component(new_options(10))
      li1 = doc |> find(suggestion_li(1)) |> List.first()
      li2 = doc |> find(suggestion_li(2)) |> List.first()

      assert text_of_attr(li1, "@mouseenter") == "setFocus(0)"
      assert text_of_attr(li2, "@mouseenter") == "setFocus(1)"

      assert text_of_attr(li1, "x-bind:class") =~ "focus === 0"
      assert text_of_attr(li2, "x-bind:class") =~ "focus === 1"
    end

    test "Alpine.js: component refers to window.suggestionsDropdown" do
      assert new_options(2)
             |> render_sample_component()
             |> find("div#input-picker-main-test-component")
             |> text_of_attr("x-data") =~ "window.suggestionsDropdown('test-component')"
    end

    test "Alpine.js: component sets up keyboard navigation" do
      main =
        new_options(2)
        |> render_sample_component()
        |> find("div#input-picker-main-test-component")

      assert text_of_attr(main, "x-on:keydown.arrow-up") == "focusPrev"
      assert text_of_attr(main, "x-on:keydown.arrow-down") == "focusNext"
      assert text_of_attr(main, "x-on:keydown.enter") == "select()"
    end

    test "Alpine.js: component sets up close on click-away" do
      assert new_options(2)
             |> render_sample_component()
             |> find("div#input-picker-main-test-component div div")
             |> text_of_attr("@click.away") == "close"
    end

    test "Alpine.js: component sets up open on focusing the display input" do
      assert new_options(2)
             |> render_sample_component()
             |> find("input#test-component")
             |> text_of_attr("x-on:focus") == "open"
    end

    test "Alpine.js: dropdown is annotated and shows when isOpen is true" do
      dropdown =
        new_options(2)
        |> render_sample_component()
        |> find("#dropdown-test-component")

      assert text_of_attr(dropdown, "x-show") == "isOpen"
      assert text_of_attr(dropdown, "x-ref") == "suggestions"
    end

    test "Dropdown shows a notice when no suggestions exist" do
      doc = render_sample_component([])

      assert text_of_element(doc, "#dropdown-test-component") ==
               "No matches found. Try searching for something different."
    end

    test "dropdown suggests user input when creatable" do
      doc =
        render_sample_component([{"USD", "US Dollar"}, {"EUR", "Euro"}],
          creatable: true,
          display_value: "Brazilian Real"
        )

      assert text_of_element(doc, "#dropdown-test-component-option-0") == "US Dollar"
      assert text_of_element(doc, "#dropdown-test-component-option-1") == "Euro"

      assert text_of_element(doc, "#dropdown-test-component-option-2") ==
               ~s(Create "Brazilian Real")

      refute text_of_element(doc, "#dropdown-test-component") ==
               "No matches found. Try searching for something different."
    end

    test "makes the html input required when required option is passed" do
      input_query = "input[type=text][required]"
      assert render_sample_component([], required: true) |> element_exists?(input_query)
      refute render_sample_component([]) |> element_exists?(input_query)
    end

    test "adds class to html element when class option is passed" do
      assert render_sample_component([], class: "animate-spin")
             |> element_exists?("#input-picker-main-test-component.animate-spin")
    end
  end

  describe "integration" do
    defmodule SampleView do
      use Phoenix.LiveView

      defmodule SampleSuggest do
        def suggest("Echo me", options) do
          [{length(options), "Echo me"}]
        end

        def suggest("all", options) do
          options
        end
      end

      def render(assigns) do
        ~H"""
        <.live_component
          submit_name="some_submit_name"
          module={PlausibleWeb.Live.Components.ComboBox}
          suggest_mod={__MODULE__.SampleSuggest}
          id="test-component"
          options={for i <- 1..20, do: {i, "Option #{i}"}}
          suggestions_limit={7}
        />
        """
      end
    end

    test "uses the suggestions module", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, SampleView, session: %{})
      doc = type_into_combo(lv, "test-component", "Echo me")
      assert text_of_element(doc, "#dropdown-test-component-option-0") == "Echo me"
    end

    test "stores selected value", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, SampleView, session: %{})
      type_into_combo(lv, "test-component", "Echo me")

      doc =
        lv
        |> element("li#dropdown-test-component-option-0 a")
        |> render_click()

      assert element_exists?(doc, "input[type=hidden][name=some_submit_name][value=20]")
    end

    test "limits the suggestions", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, SampleView, session: %{})
      doc = type_into_combo(lv, "test-component", "all")

      assert element_exists?(doc, suggestion_li(6))
      assert element_exists?(doc, suggestion_li(7))

      refute element_exists?(doc, suggestion_li(8))
      refute element_exists?(doc, suggestion_li(9))
    end

    test "clearing search input resets to all options", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, SampleView, session: %{})
      type_into_combo(lv, "test-component", "Echo me")
      doc = type_into_combo(lv, "test-component", "")

      for i <- 1..7, do: assert(element_exists?(doc, suggestion_li(i)))
    end
  end

  describe "creatable integration" do
    defmodule CreatableView do
      use Phoenix.LiveView

      def render(assigns) do
        ~H"""
        <.live_component
          submit_name="some_submit_name"
          module={PlausibleWeb.Live.Components.ComboBox}
          suggest_mod={ComboBox.StaticSearch}
          id="test-creatable-component"
          options={for i <- 1..20, do: {i, "Option #{i}"}}
          creatable
        />
        """
      end
    end

    test "stores selected value from suggestion", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, CreatableView, session: %{})
      type_into_combo(lv, "test-creatable-component", "option 20")

      doc =
        lv
        |> element("li#dropdown-test-creatable-component-option-0 a")
        |> render_click()

      assert element_exists?(doc, "input[type=hidden][name=some_submit_name][value=20]")
    end

    test "suggests creating custom value", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, CreatableView, session: %{})

      assert lv
             |> type_into_combo("test-creatable-component", "my new option")
             |> text_of_element("li#dropdown-test-creatable-component-option-0 a") ==
               ~s(Create "my new option")
    end

    test "stores new value by clicking on the dropdown custom option", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, CreatableView, session: %{})
      type_into_combo(lv, "test-creatable-component", "my new option")

      doc =
        lv
        |> element("li#dropdown-test-creatable-component-option-0 a")
        |> render_click()

      assert element_exists?(
               doc,
               "input[type=hidden][name=some_submit_name][value=\"my new option\"]"
             )
    end

    test "stores new value while typing", %{conn: conn} do
      {:ok, lv, _html} = live_isolated(conn, CreatableView, session: %{})

      assert lv
             |> type_into_combo("test-creatable-component", "my new option")
             |> element_exists?(
               "input[type=hidden][name=some_submit_name][value=\"my new option\"]"
             )
    end
  end

  defp render_sample_component(options, extra_opts \\ []) do
    render_component(
      ComboBox,
      Keyword.merge(
        [
          options: options,
          submit_name: "test-submit-name",
          id: "test-component",
          suggest_mod: ComboBox.StaticSearch
        ],
        extra_opts
      )
    )
  end

  defp new_options(n) do
    Enum.map(1..n, &{&1, "TestOption #{&1}"})
  end

  defp suggestion_li(idx) do
    ~s/#{@ul} li#dropdown-test-component-option-#{idx - 1}/
  end

  defp type_into_combo(lv, id, text) do
    lv
    |> element("input##{id}")
    |> render_change(%{
      "_target" => ["display-#{id}"],
      "display-#{id}" => "#{text}"
    })
  end
end
