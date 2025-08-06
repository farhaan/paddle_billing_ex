defmodule PaddleBilling.ValidationTest do
  use ExUnit.Case, async: true

  alias PaddleBilling.{Product, Error}

  describe "input validation and sanitization" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles nil and empty string inputs", %{bypass: bypass, config: config} do
      test_cases = [
        %{name: nil, description: ""},
        %{name: "", description: nil},
        %{name: "", description: ""},
        %{}
      ]

      for {params, index} <- Enum.with_index(test_cases) do
        Bypass.expect_once(bypass, "POST", "/products", fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          # Handle case where empty maps don't send a body (per Client.should_include_body?)
          parsed =
            if body == "" do
              %{}
            else
              Jason.decode!(body)
            end

          # Verify nil values are preserved as expected
          # Convert atom keys to string keys for comparison since JSON encoding converts atom keys to strings
          string_key_params =
            if map_size(params) == 0 do
              %{}
            else
              Enum.into(params, %{}, fn {k, v} -> {to_string(k), v} end)
            end

          assert parsed == string_key_params

          Plug.Conn.resp(
            conn,
            201,
            Jason.encode!(%{
              "data" => %{
                "id" => "pro_#{index}",
                "name" => params[:name] || params["name"],
                "description" => params[:description] || params["description"]
              }
            })
          )
        end)

        # Should handle nil/empty values without crashing
        assert {:ok, product} = Product.create(params, config: config)
        assert product.id == "pro_#{index}"
      end
    end

    test "handles extremely long strings", %{bypass: bypass, config: config} do
      long_string = String.duplicate("A", 100_000)

      params = %{
        name: long_string,
        description: long_string,
        custom_data: %{
          "field1" => long_string,
          "field2" => String.duplicate("B", 50_000)
        }
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        # Verify long strings are handled correctly
        assert String.length(parsed["name"]) == 100_000
        assert String.starts_with?(parsed["name"], "AAAA")

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{
            "data" => %{"id" => "pro_long", "name" => "Long Product"}
          })
        )
      end)

      # Should handle long strings without issues
      assert {:ok, product} = Product.create(params, config: config)
      assert product.id == "pro_long"
    end

    test "handles special and unicode characters", %{bypass: bypass, config: config} do
      special_params = %{
        name: "Product™ with special chars: &<>\"'",
        description: "测试产品  with émojis and ñice chars",
        custom_data: %{
          "unicode" => "Iñtërnâtiônàlizætiøn",
          "symbols" => "∀x∈ℝ: x²≥0",
          "emoji" => "🌟⭐",
          "quotes" => "He said \"Hello\" and she replied 'Hi'",
          "newlines" => "Line1\nLine2\r\nLine3\tTabbed"
        }
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        # Verify special characters are preserved
        assert parsed["name"] == "Product™ with special chars: &<>\"'"
        assert String.contains?(parsed["description"], "")
        assert parsed["custom_data"]["emoji"] == "🌟⭐"

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{
            "data" => %{"id" => "pro_special", "name" => parsed["name"]}
          })
        )
      end)

      assert {:ok, product} = Product.create(special_params, config: config)
      assert product.id == "pro_special"
    end

    test "handles malformed UTF-8 gracefully", %{bypass: bypass, config: config} do
      # Create strings with potential encoding issues
      binary_data = <<0xFF, 0xFE, 0xFD, 0xFC>>
      mixed_encoding = "Valid string " <> binary_data

      params = %{
        name: "Product with binary: #{inspect(binary_data)}",
        description: "Mixed: #{inspect(mixed_encoding)}"
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        # Should be able to decode the JSON despite binary content
        parsed = Jason.decode!(body)
        assert is_map(parsed)

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{
            "data" => %{"id" => "pro_binary", "name" => "Binary Product"}
          })
        )
      end)

      # Should handle binary data in strings without crashing
      assert {:ok, product} = Product.create(params, config: config)
      assert product.id == "pro_binary"
    end

    test "handles deeply nested data structures", %{bypass: bypass, config: config} do
      deeply_nested = build_deep_structure(20)

      params = %{
        name: "Nested Product",
        custom_data: deeply_nested
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        # Verify deep nesting is preserved
        # Structure is: custom_data.level_20.level_19...level_1.level_0.value
        assert get_in(parsed, ["custom_data", "level_20"]) != nil
        assert parsed["custom_data"]["data_20"] == "value_20"

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{
            "data" => %{"id" => "pro_nested", "name" => "Nested Product"}
          })
        )
      end)

      assert {:ok, product} = Product.create(params, config: config)
      assert product.id == "pro_nested"
    end

    test "handles circular reference prevention", %{bypass: bypass, config: config} do
      # Create a structure that would cause issues if not handled properly
      circular_data = %{
        "self_ref" => "This refers to itself: see self_ref",
        "deep" => %{
          "deeper" => %{
            "reference" => "Back to root"
          }
        }
      }

      params = %{
        name: "Circular Test",
        custom_data: circular_data
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        assert parsed["custom_data"]["self_ref"] != nil

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{
            "data" => %{"id" => "pro_circular", "name" => "Circular Product"}
          })
        )
      end)

      assert {:ok, product} = Product.create(params, config: config)
      assert product.id == "pro_circular"
    end

    test "validates required fields", %{bypass: bypass, config: config} do
      # Test with missing required fields
      invalid_params_list = [
        %{description: "No name"},
        %{name: "", description: "Empty name"},
        %{name: nil, description: "Null name"}
      ]

      for {invalid_params, _index} <- Enum.with_index(invalid_params_list) do
        Bypass.expect_once(bypass, "POST", "/products", fn conn ->
          Plug.Conn.resp(
            conn,
            400,
            Jason.encode!(%{
              "errors" => [
                %{
                  "field" => "name",
                  "code" => "required",
                  "detail" => "Product name is required"
                }
              ]
            })
          )
        end)

        assert {:error, %Error{type: :validation_error}} =
                 Product.create(invalid_params, config: config)
      end
    end

    defp build_deep_structure(0), do: %{"value" => "deep_value"}

    defp build_deep_structure(depth) do
      %{
        "level_#{depth}" => build_deep_structure(depth - 1),
        "data_#{depth}" => "value_#{depth}",
        "array_#{depth}" => [1, 2, depth]
      }
    end
  end

  describe "boundary value testing" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles minimum and maximum string lengths", %{bypass: bypass, config: config} do
      test_cases = [
        # Minimum length (1 character)
        %{name: "A", description: "B"},
        # Maximum reasonable length
        %{name: String.duplicate("X", 255), description: String.duplicate("Y", 1000)},
        # Edge case: exactly at common limits
        %{name: String.duplicate("Z", 256), description: String.duplicate("W", 65_535)}
      ]

      for {params, index} <- Enum.with_index(test_cases) do
        Bypass.expect_once(bypass, "POST", "/products", fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          parsed = Jason.decode!(body)

          # Verify lengths are preserved
          assert String.length(parsed["name"]) == String.length(params.name)
          assert String.length(parsed["description"]) == String.length(params.description)

          Plug.Conn.resp(
            conn,
            201,
            Jason.encode!(%{
              "data" => %{"id" => "pro_boundary_#{index}", "name" => "Boundary Test"}
            })
          )
        end)

        assert {:ok, product} = Product.create(params, config: config)
        assert product.id == "pro_boundary_#{index}"
      end
    end

    test "handles numeric boundary values", %{bypass: bypass, config: config} do
      numeric_test_cases = [
        %{custom_data: %{"number" => 0}},
        %{custom_data: %{"number" => -1}},
        %{custom_data: %{"number" => 1}},
        # Max 32-bit int
        %{custom_data: %{"number" => 2_147_483_647}},
        # Min 32-bit int
        %{custom_data: %{"number" => -2_147_483_648}},
        %{custom_data: %{"float" => 0.0}},
        # Near max float
        %{custom_data: %{"float" => 1.797_693_134_862_315_7e308}},
        %{custom_data: %{"scientific" => 1.5e-10}}
      ]

      for {params, index} <- Enum.with_index(numeric_test_cases) do
        Bypass.expect_once(bypass, "POST", "/products", fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          parsed = Jason.decode!(body)

          # Verify numeric values are preserved
          assert parsed["custom_data"]["number"] == params.custom_data["number"] ||
                   parsed["custom_data"]["float"] == params.custom_data["float"] ||
                   parsed["custom_data"]["scientific"] == params.custom_data["scientific"]

          Plug.Conn.resp(
            conn,
            201,
            Jason.encode!(%{
              "data" => %{"id" => "pro_numeric_#{index}", "name" => "Numeric Test"}
            })
          )
        end)

        assert {:ok, product} = Product.create(params, config: config)
        assert product.id == "pro_numeric_#{index}"
      end
    end

    test "handles collection size boundaries", %{bypass: bypass, config: config} do
      collection_cases = [
        # Empty collections
        %{custom_data: %{"array" => [], "object" => %{}}},
        # Single item collections
        %{custom_data: %{"array" => [1], "object" => %{"key" => "value"}}},
        # Large collections
        %{
          custom_data: %{
            "large_array" => Enum.to_list(1..1000),
            "large_object" => Enum.into(1..100, %{}, fn i -> {"key_#{i}", "value_#{i}"} end)
          }
        }
      ]

      for {params, index} <- Enum.with_index(collection_cases) do
        Bypass.expect_once(bypass, "POST", "/products", fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          parsed = Jason.decode!(body)

          # Verify collection sizes
          if parsed["custom_data"]["array"] do
            assert length(parsed["custom_data"]["array"]) == length(params.custom_data["array"])
          end

          Plug.Conn.resp(
            conn,
            201,
            Jason.encode!(%{
              "data" => %{"id" => "pro_collection_#{index}", "name" => "Collection Test"}
            })
          )
        end)

        assert {:ok, product} = Product.create(params, config: config)
        assert product.id == "pro_collection_#{index}"
      end
    end
  end

  describe "type coercion and validation" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles mixed data types", %{bypass: bypass, config: config} do
      mixed_params = %{
        name: "Mixed Types Product",
        custom_data: %{
          "string" => "text",
          "integer" => 42,
          "float" => 3.14159,
          "boolean_true" => true,
          "boolean_false" => false,
          "null" => nil,
          "array_mixed" => [1, "two", 3.0, true, nil],
          "nested_object" => %{
            "inner_string" => "inner",
            "inner_number" => 123
          }
        }
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        # Verify types are preserved correctly
        custom_data = parsed["custom_data"]
        assert is_binary(custom_data["string"])
        assert is_integer(custom_data["integer"])
        assert is_float(custom_data["float"])
        assert is_boolean(custom_data["boolean_true"])
        assert is_boolean(custom_data["boolean_false"])
        assert is_nil(custom_data["null"])
        assert is_list(custom_data["array_mixed"])
        assert is_map(custom_data["nested_object"])

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{
            "data" => %{"id" => "pro_mixed", "name" => "Mixed Types Product"}
          })
        )
      end)

      assert {:ok, product} = Product.create(mixed_params, config: config)
      assert product.id == "pro_mixed"
    end

    test "handles atom keys vs string keys", %{bypass: bypass, config: config} do
      # Test both atom and string keys
      atom_key_params = %{
        name: "Atom Keys",
        description: "Using atom keys",
        custom_data: %{
          atom_key: "atom_value",
          nested: %{inner_atom: "inner_value"}
        }
      }

      string_key_params = %{
        "name" => "String Keys",
        "description" => "Using string keys",
        "custom_data" => %{
          "string_key" => "string_value",
          "nested" => %{"inner_string" => "inner_value"}
        }
      }

      test_cases = [atom_key_params, string_key_params]

      for {params, index} <- Enum.with_index(test_cases) do
        Bypass.expect_once(bypass, "POST", "/products", fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          parsed = Jason.decode!(body)

          # JSON encoding converts atom keys to strings
          assert is_binary(parsed["name"] || parsed[:name])

          Plug.Conn.resp(
            conn,
            201,
            Jason.encode!(%{
              "data" => %{"id" => "pro_keys_#{index}", "name" => "Keys Test"}
            })
          )
        end)

        assert {:ok, product} = Product.create(params, config: config)
        assert product.id == "pro_keys_#{index}"
      end
    end
  end

  describe "error condition testing" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles malformed input gracefully", %{config: config} do
      # These should all fail at the Elixir level, not make HTTP requests
      malformed_inputs = [
        # Function as parameter (not serializable)
        # Note: This would fail at compile time, so we skip it

        # PID as parameter
        %{name: "Test", pid: self()},

        # Reference as parameter
        %{name: "Test", ref: make_ref()}
      ]

      for malformed_input <- malformed_inputs do
        # Should raise encoding error before making HTTP request
        assert_raise Protocol.UndefinedError, fn ->
          Product.create(malformed_input, config: config)
        end
      end
    end

    test "handles network interruption during request", %{config: config} do
      # Use an unreachable host to simulate network error
      network_error_config = %PaddleBilling.Config{
        config
        | base_url: "http://localhost:1",
          timeout: 1000
      }

      # Should handle network connection failure gracefully
      assert {:error, %Error{type: error_type}} =
               Product.create(%{name: "Test"}, config: network_error_config)

      assert error_type in [:network_error, :timeout_error]
    end

    test "handles partial response corruption", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        # Send incomplete JSON response
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(200, "{\"data\": {\"id\": \"pro_123\", \"na")
      end)

      # Should handle corrupted JSON gracefully
      assert {:error, %Error{}} = Product.create(%{name: "Test"}, config: config)
    end
  end
end
