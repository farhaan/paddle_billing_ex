defmodule PaddleBilling.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/farhaan/paddle_billing_ex"

  def project do
    [
      app: :paddle_billing_ex,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),

      # Documentation
      name: "PaddleBilling",
      source_url: @source_url,
      docs: docs(),

      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],

      # Dialyzer
      dialyzer: [
        plt_add_apps: [:mix],
        plt_core_path: "priv/plts",
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      # HTTP client
      {:req, "~> 0.5.15"},

      # JSON handling
      {:jason, "~> 1.4.4"},

      # HTTP server
      {:bandit, "~> 1.7"},

      # Testing
      {:bypass, "~> 2.1.0", only: :test},
      {:excoveralls, "~> 0.18.5", only: :test},
      {:ex_machina, "~> 2.8", only: :test},

      # Development tools
      {:ex_doc, "~> 0.38.2", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4.5", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7.12", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    A modern Elixir client for the Paddle Billing API.
    Supports the latest Paddle Billing features with proper authentication,
    JSON handling, and comprehensive error management.
    """
  end

  defp package do
    [
      name: "paddle_billing",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Paddle API Docs" => "https://developer.paddle.com/api-reference/overview"
      },
      maintainers: ["Your Name"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        Core: [
          PaddleBilling,
          PaddleBilling.Client,
          PaddleBilling.Config,
          PaddleBilling.Error
        ],
        Resources: [
          PaddleBilling.Product,
          PaddleBilling.Price,
          PaddleBilling.Customer,
          PaddleBilling.Subscription,
          PaddleBilling.Transaction,
          PaddleBilling.Discount,
          PaddleBilling.Event
        ],
        Webhooks: [
          PaddleBilling.Webhook,
          PaddleBilling.Webhook.Event
        ]
      ]
    ]
  end
end
