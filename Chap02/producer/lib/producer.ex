defmodule Producer do
  @moduledoc """
  Documentation for `Producer`.
  """

  use GenServer
  alias :jsx, as: JSX
  @routing_key "test_routing_key"
  @exchange "test_exchange"
  @queue "test_queue"

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

  @impl GenServer
  def init(nil) do
    Process.flag(:trap_exit, true)
    send(self(), {:init, @queue, @exchange, @routing_key})
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:publish, msg}, state) do
    AMQP.Basic.publish(state.chan, state.exchange, state.routing_key, msg)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:init, queue, exchange, routing_key}, _state) do
    {:ok, conn} = AMQP.Connection.open()
    {:ok, chan} = AMQP.Channel.open(conn)

    AMQP.Queue.declare(chan, queue)
    AMQP.Exchange.declare(chan, exchange)
    AMQP.Queue.bind(chan, queue, exchange, routing_key: routing_key)

    {:noreply,
     %{
       conn: conn,
       chan: chan,
       queue: queue,
       exchange: exchange,
       routing_key: routing_key
     }}
  end

  @impl GenServer
  def handle_info(info, state) do
    IO.puts("Info: #{inspect(info)}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    AMQP.Queue.unbind(state.chan, state.queue, state.exchange)
    AMQP.Queue.delete(state.chan, state.queue)

    AMQP.Exchange.delete(state.chan, state.exchange)

    AMQP.Channel.close(state.chan)
    AMQP.Connection.close(state.conn)
  end
end
