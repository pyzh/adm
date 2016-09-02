-module(adm_kvs).
-compile(export_all).
-include_lib("kvs/include/entry.hrl").
-include_lib("nitro/include/nitro.hrl").
-include_lib("n2o/include/wf.hrl").
-include_lib("kvs/include/feed.hrl").
-include_lib("kvs/include/kvs.hrl").

event(init) -> [ wf:update(X,?MODULE:X()) || X <- [streams,datawin,binders,boot] ];
event({binder,Name}) -> wf:update(datawin,fold_(table_fold(Name,first(Name),20,[])));
event({stream,Name}) -> Feed = case element(3,kvs:table(Name)) of
                            true -> feed;
                            F -> F end,
                        case kvs:get(Feed,Name) of
                             {ok,V} -> wf:update(datawin,fold(Name,element(#container.top,V),20));
                             _ -> wf:update(datawin,fold(Name,0,0)) end;
event(U) -> io:format("Unknown Event: ~p~n\n",[U]).

pro() ->    [ #script { src = "/static/adm.min.js"} ].
dev()  -> [ [ #script { src = lists:concat(["/n2o/protocols/",X,".js"])} || X <- [bert,nitrogen] ],
            [ #script { src = lists:concat(["/n2o/",Y,".js"])}           || Y <- [bullet,n2o,utf8,validation] ] ].
main() ->     #dtl    { file = "index", app=adm,
                        bindings = [{body,[]},
                                    {date,bpe_date:date_to_string(bpe_date:today())},
                                    {enode,lists:concat([node()])},
                                    {session,n2o_session:session_id()},
                                    {javascript,dev()}]}.

tables() -> [ element(2,T) || T <- kvs:tables() ].
containers() -> [ element(2,T) || T <- kvs:tables(), record_info(fields,container) -- element(4,T) == [] ].
iterators() -> [ element(2,T) || T <- kvs:tables(), record_info(fields,iterator) -- element(4,T) == [] ].
noniterators() -> [ element(2,T) || T <- kvs:tables(), record_info(fields,iterator) -- element(4,T) /= [] ].
binders_() -> [ X || {X,_}<- kvs:containers() ].
bsize(Config) -> lists:sum([ mnesia:table_info(Name,size) || #block{name=Name} <- Config ]).
blocks(Config) -> length(Config)+1.
row(Name) -> Config = kvs:config(Name), StrName = lists:concat([Name]),
             #tr{id=Name,cells=[#td{body=#link{id=Name,href="#",onclick="setup_window("++StrName++");",body=StrName,postback={stream,Name}}},
                                #td{body=lists:concat([blocks(Config)])},
                                #td{body=lists:concat([bsize(Config)+mnesia:table_info(Name,size)])}]}.

row2(Name) -> Config = kvs:config(Name), StrName = lists:concat([Name]),
             #tr{id=Name,cells=[#td{body=#link{id=Name,href="#",body=StrName,onclick="setup_window("++StrName++");",postback={binder,Name}}},
                                #td{body=lists:concat([kvs:count(Name)])}]}.

row3(Record) ->
             Name = element(1,Record),
             Id = element(2,Record),
             Table = kvs:table(Name),
             #tr{id=Id,cells=[#td{body=#b{body=io_lib:format("~tp",[Id])}},
                              #td{body=wf:jse(lists:concat([io_lib:format("~tp",[Record])]))}]}.

boot_() ->
  #panel{class=wizard,id=boot, body=[#h2{body="BOOT"},
      #panel{style="width:550px;font-size:12pt;background-color:white;",body="["++string:join([ atom_to_list(T)||T<-tables()],", ")++"]"}]}.

boot() ->
  #panel{class=wizard,id=boot, body=[#h2{body="BOOT"},
      #table{style="border-style:solid;border-width:1px;padding:20px;",
             body=[#thead{body=#tr{cells=[#th{body="Name"},#th{body="Size"}]}},
                   #tbody{body=[row2(Name)||Name<- tables()-- (iterators()++containers()) ]}]}]}.

streams() ->
  #panel{class=wizard,id=streams, body=[#h2{body="STREAMS"},
      #table{style="border-style:solid;border-width:1px;padding:20px;",
             body=[#thead{body=#tr{cells=[#th{body="Name"},#th{body="Blocks"},#th{body="Size"}]}},
                   #tbody{body=[row(Name)||Name<- iterators() ]}]}]}.

first(Name) -> {atomic,Key} = mnesia:transaction(fun() -> mnesia:first(Name) end), Key.
table_fold(_,_,0,Acc) -> Acc;
table_fold(Name,'$end_of_table',Count,Acc) -> Acc;
table_fold(Name,First,Count,Acc) ->
   Data = case kvs:get(Name,First) of
        {ok,D} -> D;
        _ -> [] end,
   {atomic,Key} = mnesia:transaction(fun() -> mnesia:next(Name,First) end),
   case Key of '$end_of_table' -> [Data|Acc];
                           Key -> table_fold(Name,Key,Count-1,[Data|Acc]) end.

datawin() -> fold(group,20,10).
fold_([]) -> [];
fold_(Traverse) ->
%  Rec = hd(Traverse),
%  Name = element(1,Rec),
%  Id = element(2,Rec),
%  Container = element(3,Rec),
%  Prev = element(5,Rec),
%  Next = element(6,Rec),
  #panel{class=wizard,id=datawin, body=[#h2{body="DATA WINDOW"},
      #table{style="width:100%;border-style:solid;border-width:1px;padding:20px;",
             body=[#thead{body=#tr{cells=[#th{body="No"},#th{body="Record"}]}},
                   #tbody{body=[row3(Record)||Record<- Traverse]},
                   #tfoot{body=[#th{body=#link{body="prev"}},#th{body=#link{body="next",postback={shift}}}]}
                   ]}]}.

fold(Table,Start,Count) ->
  Traverse = kvs:traversal(Table,Start,Count,#iterator.prev,#kvs{mod=store_mnesia}),
  fold_(Traverse).

binders() ->
  #panel{class=wizard,id=binders, body=[#h2{body="BINDERS"},
      #table{style="border-style:solid;border-width:1px;padding:20px;",
             body=[#thead{body=#tr{cells=[#th{body="Name"},#th{body="Size"}]}},
                   #tbody{body=[row2(Name)||Name<- containers()]}]}]}.