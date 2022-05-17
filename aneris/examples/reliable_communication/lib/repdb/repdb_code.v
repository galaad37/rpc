(* This file is automatically generated from the OCaml source file
<repository_root>/ml_sources/reliable_communication/lib/repdb/repdb_code.ml *)

From aneris.aneris_lang Require Import ast.
From aneris.aneris_lang.lib Require Import list_code.
From aneris.aneris_lang.lib Require Import queue_code.
From aneris.aneris_lang.lib Require Import map_code.
From aneris.aneris_lang.lib Require Import network_util_code.
From aneris.aneris_lang.lib.serialization Require Import serialization_code.
From aneris.examples.reliable_communication Require Import client_server_code.

(**  Serializers  *)

Definition write_serializer val_ser :=
  prod_serializer string_serializer val_ser.

Definition read_serializer := string_serializer.

Definition req_c2l_ser val_ser :=
  sum_serializer (write_serializer val_ser) read_serializer.

Definition rep_l2c_ser val_ser :=
  sum_serializer unit_serializer (option_serializer val_ser).

Definition req_f2l_ser := int_serializer.

Definition rep_l2f_ser val_ser :=
  prod_serializer (prod_serializer string_serializer val_ser) int_serializer.

Definition req_c2f_ser := read_serializer.

Definition rep_f2c_ser val_ser := option_serializer val_ser.

(**  Type definitions  *)

(**  Monitored containers  *)

Definition mcell_create : val :=
  λ: <>,
  let: "mon" := new_monitor #() in
  let: "cell" := ref NONE in
  ("mon", "cell").

Definition mcell_wait_some : val :=
  λ: "mc",
  let: "m" := Fst "mc" in
  let: "c" := Snd "mc" in
  letrec: "aux" <> :=
    match: ! "c" with
      NONE => monitor_wait "m";;
              "aux" #()
    | SOME "_v" => #()
    end in
    "aux" #().

Definition mcell_wait_none : val :=
  λ: "mc",
  let: "m" := Fst "mc" in
  let: "c" := Snd "mc" in
  letrec: "aux" <> :=
    match: ! "c" with
      NONE => #()
    | SOME "_v" => monitor_wait "m";;
                   "aux" #()
    end in
    "aux" #().

Definition mcell_set : val :=
  λ: "mc" "x",
  let: "m" := Fst "mc" in
  let: "c" := Snd "mc" in
  monitor_acquire "m";;
  mcell_wait_none "mc";;
  "c" <- (SOME "x");;
  monitor_signal "m";;
  monitor_release "m".

Definition mcell_fetch : val :=
  λ: "mc",
  let: "m" := Fst "mc" in
  let: "c" := Snd "mc" in
  monitor_acquire "m";;
  mcell_wait_some "mc";;
  let: "rep" := unSOME ! "c" in
  "c" <- NONE;;
  #();;
  monitor_signal "m";;
  monitor_release "m";;
  "rep".

Definition mqueue_create : val :=
  λ: <>,
  let: "mon" := new_monitor #() in
  let: "que" := ref (queue_empty #()) in
  ("mon", "que").

Definition mqueue_wait : val :=
  λ: "mq",
  let: "m" := Fst "mq" in
  let: "q" := Snd "mq" in
  letrec: "aux" <> :=
    (if: queue_is_empty ! "q"
     then  monitor_wait "m";;
           "aux" #()
     else  #()) in
    "aux" #().

Definition mqueue_fetch : val :=
  λ: "mq",
  let: "m" := Fst "mq" in
  let: "q" := Snd "mq" in
  monitor_acquire "m";;
  mqueue_wait "mq";;
  let: "tmp" := ! "q" in
  let: "qu" := unSOME (queue_take_opt "tmp") in
  let: "hd" := Fst "qu" in
  let: "tl" := Snd "qu" in
  "q" <- "tl";;
  #();;
  monitor_release "m";;
  "hd".

Definition mqueue_add : val :=
  λ: "mq" "x",
  let: "m" := Fst "mq" in
  let: "q" := Snd "mq" in
  monitor_acquire "m";;
  "q" <- (queue_add "x" ! "q");;
  monitor_broadcast "m";;
  monitor_release "m".

(**  Generic server library  *)

Definition request : val :=
  λ: "ch" "lk" "req",
  acquire "lk";;
  send "ch" "req";;
  let: "msg" := recv "ch" in
  release "lk";;
  "msg".

Definition requests_handler_loop : val :=
  λ: "request_handler" "ev_q",
  letrec: "loop" <> :=
    let: "req_ev" := mqueue_fetch "ev_q" in
    "request_handler" "req_ev";;
    "loop" #() in
    "loop" #().

Definition service_loop : val :=
  λ: "c" "mc" "ev_q",
  letrec: "loop" <> :=
    let: "req" := recv "c" in
    mqueue_add "ev_q" ("req", "mc");;
    let: "rep" := mcell_fetch "mc" in
    send "c" "rep";;
    "loop" #() in
    "loop" #().

Definition accept_new_connections_loop : val :=
  λ: "skt" "ev_q",
  letrec: "loop" <> :=
    let: "new_conn" := accept "skt" in
    let: "chan" := Fst "new_conn" in
    let: "_addr" := Snd "new_conn" in
    let: "cell" := mcell_create #() in
    Fork (service_loop "chan" "cell" "ev_q");;
    "loop" #() in
    "loop" #().

Definition run_server ser deser : val :=
  λ: "addr" "request_handler",
  let: "skt" := make_server_skt ser deser "addr" in
  server_listen "skt";;
  let: "evq" := mqueue_create #() in
  Fork (accept_new_connections_loop "skt" "evq");;
  Fork (requests_handler_loop "request_handler" "evq").

(**  Operations on log of requests  *)

Definition log_create : val := λ: <>, ref ([], #0).

Definition log_add_entry : val :=
  λ: "log" "req",
  let: "lp" := ! "log" in
  let: "data" := Fst "lp" in
  let: "next" := Snd "lp" in
  let: "data'" := list_append "data" [("req", "next")] in
  "log" <- ("data'", ("next" + #1)).

Definition log_next : val := λ: "log", Snd ! "log".

Definition log_length : val := λ: "log", Snd ! "log".

Definition log_get : val := λ: "log" "i", list_nth (Fst ! "log") "i".

(**  Monitored Log of write requests.  *)

Definition mlog_create : val :=
  λ: <>,
  let: "mon" := new_monitor #() in
  let: "cell" := log_create #() in
  ("mon", "cell").

Definition mlog_add_entry : val :=
  λ: "ml" "req",
  let: "m" := Fst "ml" in
  let: "log" := Snd "ml" in
  monitor_acquire "m";;
  log_add_entry "log" "req";;
  monitor_signal "m";;
  monitor_release "m".

Definition mlog_get_next : val :=
  λ: "ml" "i",
  let: "m" := Fst "ml" in
  let: "log" := Snd "ml" in
  monitor_acquire "m";;
  letrec: "aux" <> :=
    let: "n" := log_next "log" in
    (if: "n" = "i"
     then  monitor_wait "m";;
           "aux" #()
     else  monitor_release "m";;
           unSOME (log_get "log" "i")) in
    (if: ("i" < #0) || ((log_next "log") < "i")
     then  assert: #false
     else  "aux" #()).

(**  Leader  *)

Definition follower_request_handler : val :=
  λ: "mlog" "req_ev",
  let: "i" := Fst "req_ev" in
  let: "mc" := Snd "req_ev" in
  let: "rep" := mlog_get_next "mlog" "i" in
  mcell_set "mc" "rep".

Definition client_request_handler_at_leader : val :=
  λ: "db" "log" "req_ev",
  let: "req" := Fst "req_ev" in
  let: "mc" := Snd "req_ev" in
  let: "rep" := match: "req" with
    InjL "p" =>
    let: "k" := Fst "p" in
    let: "v" := Snd "p" in
    "db" <- (map_insert "k" "v" ! "db");;
    mlog_add_entry "log" ("k", "v");;
    InjL #()
  | InjR "k" => InjR (map_lookup "k" ! "db")
  end in
  mcell_set "mc" "rep".

Definition start_leader_processing_clients ser : val :=
  λ: "addr" "mlog",
  let: "db" := ref (map_empty #()) in
  run_server (rep_l2c_ser ser) (req_c2l_ser ser) "addr"
  (client_request_handler_at_leader "db" "mlog").

Definition start_leader_processing_followers ser : val :=
  λ: "addr" "log",
  run_server (rep_l2f_ser ser) req_f2l_ser "addr"
  (follower_request_handler "log").

Definition init_leader ser : val :=
  λ: "addr0" "addr1",
  let: "mlog" := mlog_create #() in
  Fork (start_leader_processing_clients ser "addr0" "mlog");;
  Fork (start_leader_processing_followers ser "addr1" "mlog").

(**  Follower.  *)

Definition client_request_handler_at_follower : val :=
  λ: "db" "req_ev",
  let: "k" := Fst "req_ev" in
  let: "mc" := Snd "req_ev" in
  let: "rep" := map_lookup "k" ! "db" in
  mcell_set "mc" "rep".

Definition start_follower_processing_clients ser : val :=
  λ: "addr" "db",
  run_server (rep_f2c_ser ser) req_c2f_ser "addr"
  (client_request_handler_at_follower "db").

Definition sync_loop : val :=
  λ: "ch" "db" "log",
  letrec: "aux" <> :=
    let: "i" := log_next "log" in
    send "ch" "i";;
    let: "rep" := recv "ch" in
    let: "k" := Fst (Fst "rep") in
    let: "v" := Snd (Fst "rep") in
    let: "j" := Snd "rep" in
    assert: ("i" = "j");;
    log_add_entry "log" ("k", "v");;
    "db" <- (map_insert "k" "v" ! "db");;
    "aux" #() in
    "aux" #().

Definition sync_with_server ser : val :=
  λ: "l_addr" "f2l_addr" "db" "log",
  let: "skt" := make_client_skt req_f2l_ser (rep_l2f_ser ser) "f2l_addr" in
  let: "ch" := connect "skt" "l_addr" in
  sync_loop "ch" "db" "log".

Definition init_follower ser : val :=
  λ: "l_addr" "f2l_addr" "f_addr",
  let: "db" := ref (map_empty #()) in
  let: "log" := log_create #() in
  sync_with_server ser "l_addr" "f2l_addr" "db" "log";;
  start_follower_processing_clients ser "f_addr" "db".

(**  Client Proxy Implementation.  *)

Definition init_client_leader_proxy ser : val :=
  λ: "clt_addr" "srv_addr",
  let: "skt" := make_client_skt (req_c2l_ser ser) (rep_l2c_ser ser)
                "clt_addr" in
  let: "ch" := connect "skt" "srv_addr" in
  let: "lk" := newlock #() in
  let: "write" := λ: "k" "v",
  match: request "ch" "lk" (InjL ("k", "v")) with
    InjL "_u" => #()
  | InjR "_abs" => assert: #false
  end in
  let: "read" := λ: "k",
  match: request "ch" "lk" (InjR "k") with
    InjL "_abs" => assert: #false
  | InjR "r" => "r"
  end in
  ("write", "read").

Definition init_client_follower_proxy ser : val :=
  λ: "clt_addr" "f_addr",
  let: "skt" := make_client_skt req_c2f_ser (rep_f2c_ser ser) "clt_addr" in
  let: "ch" := connect "skt" "f_addr" in
  let: "lk" := newlock #() in
  let: "read" := λ: "k",
  request "ch" "lk" "k" in
  "read".