-module(chat_cowboy_ws_handler).

-export([init/3]).
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).

-define(CHATROOM_NAME, ?MODULE).
-define(TIMEOUT, 5 * 60 * 1000). % Innactivity Timeout

-record(state, {name, handler}).

%% API

init(_, _Req, _Opts) ->
  {upgrade, protocol, cowboy_websocket}.

websocket_init(_Type, Req, _Opts) ->
  % Create the handler from our custom callback
  Handler = ebus_proc:spawn_handler(fun chat_erlbus_handler:handle_msg/2, [self()]),
  ebus:sub(Handler, ?CHATROOM_NAME),
  {ok, Req, #state{name = get_name(Req), handler = Handler}, ?TIMEOUT}.

websocket_handle({text, Msg}, Req, State) ->
  ebus:pub(?CHATROOM_NAME, {State#state.name, Msg}),
  {ok, Req, State};
websocket_handle(_Data, Req, State) ->
  {ok, Req, State}.

websocket_info({message_published, {Sender, Msg}}, Req, State) ->
  Payload = jiffy:decode(Msg, [return_maps]),
  Timestamp = maps:get(<<"timestamp">>, Payload),
  Message = maps:get(<<"txt">>, Payload),
  {reply, {text, jiffy:encode({[{sender, Sender}, {msg, Message}, {timestamp, Timestamp}]})}, Req, State};

websocket_info(_Info, Req, State) ->
  {ok, Req, State}.

websocket_terminate(_Reason, Req, State) ->
  % Unsubscribe the handler
  ebus:unsub(State#state.handler, ?CHATROOM_NAME),
  ok.

%% Private methods

get_name(Req) ->
  {Username, _} = cowboy_req:binding(username, Req),
  Name = list_to_binary(string:join([binary_to_list(Username)], "")),
  Name.
  