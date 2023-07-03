defmodule Producer do
  @moduledoc """
  Documentation for `Producer`.
  """

  use Application

  @type type() :: :normal |
                  {:takeover, node()} |
                  {:failover, node()}
  @type args() :: list()

  @spec start(type(), args()) :: {:ok, pid()}
  def start(_type, _args) do
    Supervisor.start_link([Producer.Publisher], strategy: :one_for_one)
  end
end
