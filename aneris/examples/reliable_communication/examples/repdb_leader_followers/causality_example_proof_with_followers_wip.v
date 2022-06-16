From iris.algebra Require Import excl.
From iris.base_logic.lib Require Import invariants.
From aneris.aneris_lang Require Import ast.
From aneris.aneris_lang.lib.serialization Require Import serialization_code.
From aneris.aneris_lang Require Import lang.
From aneris.aneris_lang Require Import tactics proofmode.
From aneris.aneris_lang.program_logic
     Require Import aneris_weakestpre aneris_lifting.
From aneris.aneris_lang.lib Require Import assert_proof.
From aneris.aneris_lang.lib.serialization Require Import serialization_proof.
From aneris.examples.reliable_communication.prelude
     Require Import ser_inj.
From aneris.examples.reliable_communication.lib.repdb
     Require Import repdb_code.
From aneris.examples.reliable_communication.lib.repdb.spec
     Require Import ras events resources api_spec.
From aneris.examples.reliable_communication.examples.repdb_leader_followers
     Require Import causality_example_code.
From aneris.aneris_lang.program_logic Require Import lightweight_atomic.


Section proof_of_code.
  Context `{!anerisG Mdl Σ}.
  Context `{TM: !DB_time, !DBPreG Σ}.
  Context (leader_si : message → iProp Σ).
  Context (db_sa db_Fsa : socket_address).

  (* ------------------------------------------------------------------------ *)
  (** The definition of the parameters for DB and DL and shared resources. *)
  (* ------------------------------------------------------------------------ *)

  Local Instance DBSrv : DB_params :=
    {|
      DB_addr := db_sa;
      DB_addrF := db_Fsa;
      DB_keys := {["x"; "y"]};
      DB_InvName := (nroot .@ "DBInv");
      DB_serialization := int_serialization;
      DB_ser_inj := int_ser_is_ser_injective;
      DB_ser_inj_alt := int_ser_is_ser_injective_alt
    |}.

  Context `{!@DB_resources _ _ _ _ DBSrv}.

  Definition token (γ : gname) : iProp Σ := own γ (Excl ()).

  Lemma token_exclusive (γ : gname) : token γ -∗ token γ -∗ False.
  Proof. iIntros "H1 H2". by iDestruct (own_valid_2 with "H1 H2") as %?. Qed.

  Definition Ny := nroot.@"y".
  Definition Nx := nroot.@"x".

  Definition inv_x (γ : gname) (a : we) : iProp Σ :=
    ("x" ↦ₖ Some a ∗ ⌜we_val a = #37⌝) ∨ token γ.

  (* NB : seems too strong to prove at the do_reads, because of discrepancy
     between Obs DB_addr h and Obs follower_addr hy with hy ≤ₚ h... *)
  Definition inv_y (γ : gname) : iProp Σ :=
    ∃ h owe, Obs DB_addr h ∗ ⌜at_key "y" h = owe⌝ ∗ "y" ↦ₖ owe ∗
             ∀ a, (⌜owe = Some a ∧ we_val a = (# 1)⌝) →
                  (∃ a', ⌜a' <ₜ a⌝ ∗ inv Nx (inv_x γ a')).

(* Maybe an alternative definition ?
   I believe it would work at reads, but it is hard to prove at writes now. *)
(*
  Definition inv_y (γ : gname) : iProp Σ :=
    ∃ h owe, Obs DB_addr h ∗ ⌜at_key "y" h = owe⌝ ∗ "y" ↦ₖ owe ∗
           (∀ hy a, ⌜hy ≤ₚ h⌝ ∗ ⌜at_key "y" hy = Some a⌝ ∗ ⌜we_val a = #1⌝ →
                    ∃ a', ⌜a' <ₜ a⌝ ∗ inv Nx (inv_x γ a')).
   *)

  Lemma wp_do_writes wr clt_00 γ :
    GlobalInv -∗
    inv Ny (inv_y γ) -∗
    write_spec wr clt_00 -∗
    Obs DB_addr [] -∗
    {{{ "x" ↦ₖ None }}}
      do_writes wr @[ip_of_address clt_00]
    {{{ RET #(); True }}}.
  Proof.
    iIntros "#HGinv #Hinv #Hwr #Hobs".
    iIntros "!>" (Φ) "Hx HΦ".
    iDestruct (get_simplified_write_spec with "Hwr") as "#Hswr".
    iDestruct (write_spec_write_spec_atomic with "Hwr") as "#Hawr".
    iClear "Hwr".
    wp_lam.
    wp_apply ("Hswr" $! _ (SerVal #37) with "[] [Hx]"); [done| |].
    { iExists _. iFrame "#∗". done. }
    iDestruct 1 as (h a Hkey Hval Hatkey) "[#Hobs' Hx]".
    wp_pures.
    iMod (inv_alloc Nx _ (inv_x γ a) with "[Hx]") as "#HIx".
    { iModIntro. iLeft. eauto with iFrame. }
    wp_apply ("Hawr" $! (⊤ ∖ ↑Ny) _ (SerVal #1)); [solve_ndisj|done|].
    iInv Ny as "IH" "Hclose".
    iDestruct "IH" as (h' owe) "(#>Hobs'' & >%Hatkey' & >Hy & _)".
    iMod (Obs_compare with "HGinv Hobs' Hobs''") as %Hprefix; [solve_ndisj|].
    iAssert (∃ hmax, ⌜(h ++ [a]) `prefix_of` hmax⌝ ∗
                     ⌜h' `prefix_of` hmax⌝ ∗
                     Obs DB_addr hmax)%I
      as (hmax Hhmax1 Hhmax2) "Hobs'''".
    { destruct Hprefix as [Hprefix | Hprefix].
      - by iExists _; iFrame "Hobs''".
      - by iExists _; iFrame "Hobs'". }
    rewrite -Hatkey'.
    iMod (OwnMemKey_obs_frame_prefix with "HGinv [$Hy $Hobs''']")
      as "[Hy %Hatkey'']"; [solve_ndisj|done|].
    rewrite Hatkey'.
    iModIntro.
    iExists hmax, owe.
    rewrite -Hatkey''.
    iFrame "#∗".
    iSplit; [done|].
    iNext.
    iIntros (h'' a').
    iDestruct 1 as (Hatkey''' Hkey' Hval' Hle) "[Hy Hobs'''']".
    simpl in *.
    iMod ("Hclose" with "[-HΦ]"); [|by iApply "HΦ"].
    iNext.
    iExists (hmax ++ h'' ++ [a']), (Some a'). iFrame.
    iSplit; [|].
    { iPureIntro.
      rewrite /at_key !assoc hist_at_key_add_r_singleton; [|done].
      apply last_snoc. }
    iIntros (a'' [Heq Heq']).
    simplify_eq.
    iExists a.
    iFrame "#".
    iPureIntro.
    apply Hle.
    eapply elem_of_prefix; [|apply Hhmax1].
    set_solver.
  Qed.

Definition read_at_follower_spec
           (rd : val) (csa f2csa : socket_address) (k : Key) (h : ghst) : iProp Σ :=
      ⌜k ∈ DB_keys⌝ -∗
    {{{ Obs f2csa h }}}
      rd #k @[ip_of_address csa]
    {{{vo, RET vo;
          ∃ h', ⌜h ≤ₚ h'⌝ ∗ Obs f2csa h' ∗
         ((⌜vo = NONEV⌝ ∗ ⌜at_key k h' = None⌝) ∨
         (∃ a, ⌜vo = SOMEV (we_val a)⌝ ∗ ⌜at_key k h' = Some a⌝))
    }}}%I.

  Lemma wp_wait_on_read_at_follower clt_00 fsa γ rd h0:
    GlobalInv -∗
    (∀ k h, read_at_follower_spec rd clt_00 fsa k h) -∗
    {{{ inv Ny (inv_y γ) ∗ Obs fsa h0 }}}
      wait_on_read rd #"y" #1 @[ip_of_address clt_00]
    {{{ h' a, RET #();
        ⌜h0 `prefix_of` h'⌝ ∗ Obs fsa h' ∗
        ⌜(we_val a) = #1⌝ ∗ ⌜at_key "y" h' = Some a⌝ }}}.
  Proof.
    iIntros "#HGinv #Hard".
    iIntros "!>" (Φ) "(#Hinv & #HobsF) HΦ".
    wp_lam.
    do 7 wp_pure _.
    iLöb as "IH".
    wp_pures.
    wp_apply ("Hard" $! "y" ); [done|done|].
    iIntros (w).
    iDestruct 1 as (h') "(%Hprefix & #HobsF' & [(-> & %Hatkey)|(%a & -> & %Hatkey)]) /=".
    { do 7 wp_pure _. iApply ("IH" with "HΦ"). }
    wp_pures.
    case_bool_decide as Ha.
    { wp_pure _.
      iApply ("HΦ" $! h' a).
      naive_solver. }
    do 3 wp_pure _.
    iApply ("IH" with "HΦ").
  Qed.

  Lemma wp_do_reads clt_00 fsa γ rd h0 :
    GlobalInv -∗
    (∀ k h, read_at_follower_spec rd clt_00 fsa k h) -∗
    inv Ny (inv_y γ) -∗
    {{{ Obs fsa h0 ∗ token γ }}}
      do_reads rd @[ip_of_address clt_00]
    {{{ RET #(); True }}}.
  Proof.
  Admitted.
  (*
    iIntros "#HGinv #Hard #Hinvy".
    iIntros "!>" (Φ) "(#HobsF & Htok) HΦ".
    wp_lam.
    wp_apply (wp_wait_on_read_at_follower with "[HobsF]"); [ done|done|eauto|].
    iIntros (hy a) "(%Hprefix & #HobsF' & %Heq & %Hatkey)".
    wp_pures.
    wp_apply fupd_aneris_wp.
    iInv Ny as "H" "Hcl".
    iDestruct "H" as (h wo) "(>HyobsF & >%Hyk & >Hy & H)".
    rewrite -Hyk.
    iMod (OwnMemKey_allocated "y" 1%Qp hy h a with "[][HGinv Hy]") as "Hf";
    [solve_ndisj|admit|done|iFrame "#"|iFrame|].
    (* iMod (OwnMemKey_obs_frame_prefix with "[$HGinv][$Hy]"); [solve_ndisj| | |]. *)
    (* admit. *)
    iAssert (▷ ∃ a', ⌜a' <ₜ a⌝ ∗ inv Nx (inv_x γ a'))%I as "#He".
    { iNext.
      iDestruct ("H" $! a with "[]") as (a') "Ha'".
      {  iPureIntro. iSplit; last naive_solver. split; first set_solver.
        rewrite erasure_val; done. }
      rewrite erasure_time; eauto. }
    assert (e ∈ s2).
    { by eapply elem_of_Maximals_restrict_key. }
    iMod ("Hcl" with "[Hy H]") as "_".
    { iNext; iExists _; iFrame. }


    wp_apply ("Hard"); [done..|].
    iIntros (vo) "Hpost".
    wp_apply fupd_aneris_wp.
    iDestruct "Hpost"
      as (hx) "(%Hxprefix & #HxobsF & [(-> & %Hxatkey)|(%ax & -> & %Hxatkey)]) /=".
    iInv Nx as "HI" "Hclose".
    iDestruct "HI" as "[>[Hx %Hval]|>HI]"; last first.
    { iDestruct (token_exclusive with "Htok HI") as "[]". }
    iMod (OwnMemKey_some_obs_we with "HGinv Hx") as "[Hx H]"; [solve_ndisj|].
    iDestruct "H" as (h) "[#Hobs %Hatkey]".
    iModIntro.
    iExists _, _, _.
    iFrame "#∗".
    iSplit; [done|].
    iIntros "!> [[%Heq _]|H]"; [done|].
    iDestruct "H" as (e) "[%Heq Hx]".
    simplify_eq.
    iMod ("Hclose" with "[Htok]").
    { by iRight. }
    iModIntro.
    do 2 wp_pure _.
    wp_apply wp_assert.
    wp_pures.
    rewrite Hval.
    iSplit; [done|].
    by iApply "HΦ".
  Qed.
   *)

End proof_of_code.