(* This file is automatically generated from the OCaml source file
<repository_root>/ml_sources/crdt/oplib/examples/mvreg/mvreg_code.ml *)

From aneris.aneris_lang Require Import ast.
From aneris.aneris_lang.lib.serialization Require Import serialization_code.
From aneris.aneris_lang.lib Require Import list_code.
From aneris.aneris_lang.lib.vector_clock Require Import vector_clock_code.
From aneris.examples.crdt.oplib Require Import oplib_code.

Definition init_st : val := λ: <>, [].

Definition effect : val :=
  λ: "msg" "reg",
  let: "v" := Fst (Fst "msg") in
  let: "vc" := Snd (Fst "msg") in
  let: "_u" := Snd "msg" in
  let: "vals" := let: "is_conc" := λ: "p",
                 let: "vc'" := Snd "p" in
                 assert: (~ (vect_leq "vc" "vc'"));;
                 vect_conc "vc'" "vc" in
                 list_filter "is_conc" "reg" in
  ("v", "vc") :: "vals".

Definition mvreg_crdt : val := λ: <>, (init_st, effect).

Definition mvreg_init : val :=
  λ: "addrs" "rid",
  let: "initRes" := oplib_init int_ser int_deser "addrs" "rid" mvreg_crdt in
  let: "get_state" := Fst "initRes" in
  let: "update" := Snd "initRes" in
  ("get_state", "update").