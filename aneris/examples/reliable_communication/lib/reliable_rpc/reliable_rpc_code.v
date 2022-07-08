(* This file is automatically generated from the OCaml source file
<repository_root>/ml_sources/examples/reliable_communication/lib/reliable_rpc/reliable_rpc_code.ml *)

From aneris.aneris_lang Require Import ast.
From aneris.aneris_lang.lib Require Import network_util_code.
From aneris.examples.reliable_communication Require Import client_server_code.
From aneris.aneris_lang.lib Require Import map_code.
From aneris.aneris_lang.lib.serialization Require Import serialization_code.

Definition implement : val :=
  λ: "rpc" "f",
  (Fst "rpc", λ: "s_arg", let: "arg" := Snd (Fst (Snd "rpc")) "s_arg" in
                           Fst (Snd (Snd "rpc")) ("f" "arg")).

Definition call_handler : val :=
  λ: "handlers" "name" "s_arg",
  let: "func" := unSOME (map_lookup "name" "handlers") in
  "func" "s_arg".

Definition service_loop : val :=
  λ: "c" "handlers" <>,
  letrec: "loop" <> :=
    let: "msg" := recv "c" in
    let: "name" := Fst "msg" in
    let: "s_arg" := Snd "msg" in
    let: "s_resp" := call_handler "handlers" "name" "s_arg" in
    send "c" "s_resp";;
    "loop" #() in
    "loop" #().

Definition accept_new_connections_loop : val :=
  λ: "skt" "handlers" <>,
  letrec: "loop" <> :=
    let: "new_conn" := accept "skt" in
    let: "c" := Fst "new_conn" in
    let: "_a" := Snd "new_conn" in
    Fork (service_loop "c" "handlers" #());;
    "loop" #() in
    "loop" #().

Definition req_serializer :=
  prod_serializer string_serializer string_serializer.

Definition resp_serializer := string_serializer.

Definition init_server_stub : val :=
  λ: "addr" "handlers",
  let: "skt" := make_server_skt resp_serializer req_serializer "addr" in
  server_listen "skt";;
  accept_new_connections_loop "skt" "handlers" #().

Definition init_client_stub : val :=
  λ: "clt_addr" "srv_addr",
  let: "skt" := make_client_skt req_serializer resp_serializer "clt_addr" in
  let: "ch" := connect "skt" "srv_addr" in
  let: "lk" := newlock #() in
  ("ch", "lk").

Definition call : val :=
  λ: "chan" "rpc" "arg",
  let: "ch" := Fst "chan" in
  let: "lk" := Snd "chan" in
  let: "s_arg" := Fst (Fst (Snd "rpc")) "arg" in
  let: "msg" := (Fst "rpc", "s_arg") in
  acquire "lk";;
  send "ch" "msg";;
  let: "s_resp" := recv "ch" in
  release "lk";;
  Snd (Snd (Snd "rpc")) "s_resp".
