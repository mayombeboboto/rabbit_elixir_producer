defmodule Producer.MixProject do
  use Mix.Project

  def project do
    [
      app: :producer,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jsx, "~> 3.1"},
      {:amqp, "~> 3.2"},
      {:uuid, "~> 1.1"}
    ]
  end
end
