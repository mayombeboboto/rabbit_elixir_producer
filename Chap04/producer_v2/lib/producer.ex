defmodule Producer do
  @moduledoc """
  Documentation for `Producer`.
  """

  use GenServer
  alias :jsx, as: JSX
  @routing0 "test_routing_key0"
  @routing1 "test_routing_key1"

  @exchange0 "default_exchange"
  @exchange1 "alternate_exchange"

  @queue0 "test_queue0"
  @queue1 "test_queue1"

  # APIs
  @spec start_link() :: {:ok, pid()}
  def start_link() do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec stop() :: no_return()
  def stop() do
    GenServer.stop(__MODULE__, :normal)
  end

  @spec publish_msg(%{}) :: no_return()
  def publish_msg(msg) do
    GenServer.cast(__MODULE__, {:publish, JSX.encode(msg)})
  end

  # Callback Functions
  @impl GenServer
  def init(nil) do
    Process.flag(:trap_exit, true)
    send(self(), :init)
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:publish, msg}, state) do
    AMQP.Basic.publish(state.chan, @exchange1, @routing1, msg)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:init, _state) do
    {:ok, conn} = AMQP.Connection.open()
    {:ok, chan} = AMQP.Channel.open(conn)

    AMQP.Queue.declare(chan, @queue0)
    AMQP.Queue.declare(chan, @queue1)

    AMQP.Exchange.declare(chan, @exchange0)

    # A message sent to this exchange would be routed to @exchange0
    # In case of incorrect route.
    AMQP.Exchange.declare(chan, @exchange1, :direct, [{'alternate-exchange', @exchange0}])
    AMQP.Queue.bind(chan, @queue0, @exchange0, routing_key: @routing0)
    AMQP.Queue.bind(chan, @queue1, @exchange1, routing_key: @routing1)

    {:noreply, %{conn: conn, chan: chan}}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :ok
  end
end
