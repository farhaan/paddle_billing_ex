#!/usr/bin/env elixir

Mix.install([
  {:jason, "~> 1.4"},
  {:req, "~> 0.4"},
  {:yaml_elixir, "~> 2.9"}
])

defmodule APICoverage do
  def main(args) do
    case args do
      [spec_path] -> 
        show_coverage(spec_path)
      [spec_path, output] ->
        show_coverage(spec_path)
        generate_tests(spec_path, output)
      _ ->
        IO.puts("Usage: elixir api_coverage.exs <spec_file> [test_output]")
    end
  end

  defp show_coverage(spec_path) do
    IO.puts("Analyzing API coverage from: #{spec_path}")
    
    spec = load_spec(spec_path)
    endpoints = extract_endpoints(spec)
    
    IO.puts("Found #{length(endpoints)} endpoints:")
    
    total = length(endpoints)
    
    implemented_count = 
      for endpoint <- endpoints do
        {mod, fun, arity} = get_expected_implementation(endpoint)
        status = if function_exported?(mod, fun, arity), do: "[✓]", else: "[✗]"
        IO.puts("  #{status} #{endpoint.method} #{endpoint.path} -> #{inspect(mod)}.#{fun}/#{arity}")
        
        function_exported?(mod, fun, arity)
      end
      |> Enum.count(& &1)
    
    percentage = if total > 0, do: round(implemented_count * 100 / total), else: 0
    IO.puts("\nCoverage: #{implemented_count}/#{total} (#{percentage}%)")
  end

  defp generate_tests(spec_path, output_file) do
    spec = load_spec(spec_path)
    endpoints = extract_endpoints(spec)
    
    content = [
      "defmodule PaddleBilling.APICoverageTest do",
      "  @moduledoc \"Generated API coverage tests\"",
      "  use ExUnit.Case",
      "",
      generate_tests_content(endpoints),
      "end"
    ]
    |> Enum.join("\n")
    
    File.write!(output_file, content)
    IO.puts("Tests written to: #{output_file}")
  end

  defp generate_tests_content(endpoints) do
    grouped = Enum.group_by(endpoints, fn ep -> 
      List.first(ep.tags) || "General"
    end)
    
    for {tag, tag_endpoints} <- grouped do
      test_cases = for endpoint <- tag_endpoints do
        {mod, fun, arity} = get_expected_implementation(endpoint)
        test_name = make_test_name(endpoint)
        
        "    test \"#{test_name}\" do\n" <>
        "      assert function_exported?(#{inspect(mod)}, :#{fun}, #{arity})\n" <>
        "    end"
      end
      
      "  describe \"#{tag}\" do\n" <>
      Enum.join(test_cases, "\n\n") <>
      "\n  end"
    end
    |> Enum.join("\n\n")
  end

  defp make_test_name(endpoint) do
    summary = endpoint.summary || ""
    if summary != "" do
      "implements " <> String.downcase(summary)
    else
      "implements #{String.downcase(endpoint.method)} #{endpoint.path}"
    end
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp load_spec(path) do
    content = if String.starts_with?(path, "http") do
      Req.get!(path).body
    else
      File.read!(path)
    end
    
    case Path.extname(path) do
      ext when ext in [".yaml", ".yml"] -> 
        YamlElixir.read_from_string!(content)
      ".json" -> 
        PaddleBilling.JSON.decode!(content)
      _ ->
        case PaddleBilling.JSON.decode(content) do
          {:ok, data} -> data
          {:error, _} -> YamlElixir.read_from_string!(content)
        end
    end
  end

  defp extract_endpoints(spec) do
    paths = Map.get(spec, "paths", %{})
    
    for {path, operations} <- paths,
        method <- ~w[get post put patch delete],
        Map.has_key?(operations, method) do
      
      op = Map.get(operations, method)
      
      %{
        path: path,
        method: String.upcase(method),
        summary: Map.get(op, "summary"),
        tags: Map.get(op, "tags", [])
      }
    end
  end

  defp get_expected_implementation(endpoint) do
    has_id = String.contains?(endpoint.path, "{")
    parts = endpoint.path
    |> String.split("/")
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "{")))
    
    case {endpoint.method, parts, has_id} do
      {"GET", ["products"], false} -> {PaddleBilling.Product, :list, 2}
      {"POST", ["products"], false} -> {PaddleBilling.Product, :create, 2}
      {"GET", ["products"], true} -> {PaddleBilling.Product, :get, 3}
      {"PATCH", ["products"], true} -> {PaddleBilling.Product, :update, 3}
      
      {"GET", ["prices"], false} -> {PaddleBilling.Price, :list, 2}
      {"POST", ["prices"], false} -> {PaddleBilling.Price, :create, 2}
      {"GET", ["prices"], true} -> {PaddleBilling.Price, :get, 3}
      {"PATCH", ["prices"], true} -> {PaddleBilling.Price, :update, 3}
      
      {"GET", ["customers"], false} -> {PaddleBilling.Customer, :list, 2}
      {"POST", ["customers"], false} -> {PaddleBilling.Customer, :create, 2}
      {"GET", ["customers"], true} -> {PaddleBilling.Customer, :get, 3}
      {"PATCH", ["customers"], true} -> {PaddleBilling.Customer, :update, 3}
      
      {"GET", ["subscriptions"], false} -> {PaddleBilling.Subscription, :list, 2}
      {"POST", ["subscriptions"], false} -> {PaddleBilling.Subscription, :create, 2}
      {"GET", ["subscriptions"], true} -> {PaddleBilling.Subscription, :get, 3}
      {"PATCH", ["subscriptions"], true} -> {PaddleBilling.Subscription, :update, 3}
      
      _ ->
        method_atom = endpoint.method |> String.downcase() |> String.to_atom()
        {PaddleBilling.Client, method_atom, 3}
    end
  end
end

APICoverage.main(System.argv())