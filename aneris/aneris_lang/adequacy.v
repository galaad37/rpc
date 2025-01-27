From stdpp Require Import finite.
From iris.algebra Require Import auth.
From iris.proofmode Require Import tactics.
From trillium.prelude Require Import quantifiers classical_instances finitary.
From trillium.program_logic Require Export weakestpre adequacy.
From aneris.lib Require Import gen_heap_light.
From aneris.prelude Require Export gmultiset.
From aneris.aneris_lang.state_interp Require Export state_interp.
From aneris.aneris_lang Require Export lang resources network.
From aneris.algebra Require Import disj_gsets.
Set Default Proof Using "Type".

Definition aneris_model_rel_finitary (Mdl : Model) :=
  ∀ mdl : Mdl, smaller_card {mdl' : Mdl | Mdl mdl mdl'} nat.

Definition wp_group_proto `{anerisPreG Σ Mdl} IPs A B
           (lbls: gset string)
           (obs_send_sas obs_rec_sas : gset socket_address_group) s e ip φ :=
  (∀ (aG : anerisG Mdl Σ), ⊢ |={⊤}=> ∃ (f : socket_address_group → socket_interp Σ),
     fixed_groups A -∗
     ([∗ set] sag ∈ A, sag ⤇* (f sag)) -∗
     ([∗ set] sagB ∈ B, sagB ⤳*[bool_decide (sagB ∈ obs_send_sas), bool_decide (sagB ∈ obs_rec_sas)] (∅, ∅)) -∗
     frag_st Mdl.(model_state_initial) -∗
     ([∗ set] i ∈ IPs, free_ip i) -∗
     is_node ip -∗
     ([∗ set] lbl ∈ lbls, alloc_evs lbl []) -∗
     ([∗ set] sag ∈ obs_send_sas, sendon_evs_groups sag []) -∗
     ([∗ set] sag ∈ obs_rec_sas, receiveon_evs_groups sag []) -∗
     observed_send_groups obs_send_sas -∗
     observed_receive_groups obs_rec_sas ={⊤}=∗
     WP (mkExpr ip e) @ s; (ip, 0); ⊤ {{v, ⌜φ v⌝ }}).

Definition wp_group_single_proto `{anerisPreG Σ Mdl} IPs A B
           (lbls: gset string)
           (obs_send_sas obs_rec_sas : gset socket_address) s e ip φ :=
  (∀ (aG : anerisG Mdl Σ), ⊢ |={⊤}=> ∃ (f : socket_address → socket_interp Σ),
     fixed A -∗
     ([∗ set] a ∈ A, a ⤇1 (f a)) -∗
     ([∗ set] b ∈ B, b ⤳1[bool_decide (b ∈ obs_send_sas), bool_decide (b ∈ obs_rec_sas)] (∅, ∅)) -∗
     frag_st Mdl.(model_state_initial) -∗
     ([∗ set] i ∈ IPs, free_ip i) -∗
     is_node ip -∗
     ([∗ set] lbl ∈ lbls, alloc_evs lbl []) -∗
     ([∗ set] sa ∈ obs_send_sas, sendon_evs sa []) -∗
     ([∗ set] sa ∈ obs_rec_sas, receiveon_evs sa []) -∗
     observed_send obs_send_sas -∗
     observed_receive obs_rec_sas ={⊤}=∗
     WP (mkExpr ip e) @ s; (ip,0); ⊤ {{v, ⌜φ v⌝ }}).

Theorem adequacy_groups `{anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)} IPs A B C
        (lbls: gset string)
        (obs_send_sas obs_rec_sas : gset socket_address_group)
        s e ip σ φ :
  all_disjoint C →
  set_Forall (λ sag, sag ≠ ∅) C →
  set_Forall is_singleton (C ∖ A) →
  A ⊆ C → B ⊆ C → obs_send_sas ⊆ C → obs_rec_sas ⊆ C →
  aneris_model_rel_finitary Mdl →
  wp_group_proto IPs A B lbls obs_send_sas obs_rec_sas s e ip φ →
  ip ∉ IPs →
  dom (state_ports_in_use σ) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ !! ip = Some ∅) →
  (∀ sag sa, sag ∈ A → sa ∈ sag → ip_of_address sa ∈ IPs) →
  state_heaps σ = {[ip:=∅]} →
  state_sockets σ = {[ip:=∅]} →
  state_ms σ = ∅ →
  adequate s (mkExpr ip e) σ (λ v _, φ v).
Proof.
  intros Hdisj Hne Hsingle HAle HBle Hsendle Hrecvle.
  intros HMdlfin Hwp Hipdom Hpiiu Hip Hfixdom Hste Hsce Hmse.
  eapply (adequacy_xi _ _ _ _ (sim_rel (λ _ _, True))  _ _ _
                      (Mdl.(model_state_initial) : mstate (aneris_to_trace_model Mdl))).
  { by eapply aneris_sim_rel_finitary. }
  iIntros (?) "/=".
  iMod node_gnames_auth_init as (γmp) "Hmp".
  iMod saved_si_init as (γsi) "[Hsi Hsi']".
  iMod (fixed_address_groups_init A) as (γsif) "#Hsif".
  iMod (free_ips_init IPs) as (γips) "[HIPsCtx HIPs]".
  iMod free_ports_auth_init as (γpiu) "HPiu".
  iMod (fixed_address_groups_init obs_send_sas) as
      (γobserved_send) "#Hobserved_send".
  iMod (fixed_address_groups_init obs_rec_sas) as
      (γobserved_receive) "#Hobserved_receive".
  iMod (socket_address_group_ctx_init) as (γC) "Hauth"; [done|].
  iMod (socket_address_group_own_alloc_subseteq _ C A with "Hauth") as
      "[Hauth HownA]"; [done|].
  iDestruct (socket_address_group_own_big_sepS with "HownA") as "HownAS".
  iMod (socket_address_group_own_alloc_subseteq _ C B with "Hauth") as
      "[Hauth HownB]"; [done|].
  iDestruct (socket_address_group_own_big_sepS with "HownB") as "HownBS".
  iMod (messages_ctx_init B _ _ _ _ with "HownBS Hobserved_send Hobserved_receive" ) as (γms) "[Hms HB]".
  iMod steps_init as (γsteps) "[Hsteps _]".
  iMod (model_init Mdl.(model_state_initial)) as (γm) "[Hmfull Hmfrag]".
  assert (rtc Mdl Mdl.(model_state_initial) Mdl.(model_state_initial)).
  { constructor. }
  iMod (alloc_evs_init lbls) as (γalevs) "[Halobctx Halobs]".
  iMod (sendreceive_evs_init obs_send_sas) as
      (γsendevs) "[Hsendevsctx Hsendevs]".
  iMod (sendreceive_evs_init obs_rec_sas) as
    (γreceiveevs) "[Hreceiveevsctx Hreceiveevs]".
  set (dg :=
         {|
           aneris_node_gnames_name := γmp;
           aneris_si_name := γsi;
           aneris_socket_address_group_name := γC;
           aneris_fixed_socket_address_groups_name := γsif;
           aneris_freeips_name := γips;
           aneris_freeports_name := γpiu;
           aneris_messages_name := γms;
           aneris_model_name := γm;
           aneris_steps_name := γsteps;
           aneris_allocEVS_name := γalevs;
           aneris_sendonEVS_name := γsendevs;
           aneris_receiveonEVS_name := γreceiveevs;
           aneris_observed_send_name := γobserved_send;
           aneris_observed_recv_name := γobserved_receive;
         |}).
  iMod (Hwp dg) as (f) "Hwp".
  iMod (saved_si_update A with "[$Hsi $Hsi']") as (M HMfs) "[HM Hsa]".
  assert (dom M = A) as Hdmsi.
  { apply set_eq => ?.
    split; intros ?%elem_of_elements;
      apply elem_of_elements; [by rewrite -HMfs|].
    by rewrite HMfs. }
  iAssert ([∗ set] s ∈ A, s ⤇* f s)%I as "#Hsa'".
  { rewrite -Hdmsi -!big_sepM_dom.
    iDestruct (big_sepM_sep with "[$HownAS $Hsa]") as "Hsa".
    iApply (big_sepM_impl with "[$Hsa]"); simpl; auto.
    iIntros "!>" (? ? Hx) "[? ?]"; iExists _. iFrame. }
  iMod (node_ctx_init ∅ ∅) as (γn) "[Hh Hs]".
  iMod (node_gnames_alloc γn _ ip with "[$]") as "[Hmp #Hγn]"; [done|].
  iAssert (is_node ip) as "Hn".
  { iExists _. eauto. }
  iExists
    (λ ex atr,
      aneris_events_state_interp ex ∗
      aneris_state_interp
        (trace_last ex).2
        (trace_messages_history ex) ∗
      auth_st (trace_last atr) ∗
        ⌜valid_state_evolution ex atr⌝ ∗
        steps_auth (trace_length ex))%I, (λ _ _, True)%I, _, (λ _ _, True)%I.
  iSplitR; [iApply config_wp_correct|].
  iMod (socket_address_group_own_alloc_subseteq _ C obs_send_sas with "Hauth")
    as "[Hauth Hown_send]"; [done|].
  iDestruct (socket_address_group_own_big_sepS with "Hown_send") as "Hown_send".
  iMod (socket_address_group_own_alloc_subseteq _ C obs_rec_sas with "Hauth")
    as "[Hauth Hown_recv]"; [done|].
  iDestruct (socket_address_group_own_big_sepS with "Hown_recv") as "Hown_recv".
  iSplitR.
  { eauto. }
  iSplitR "Hwp HIPs HB Hmfrag Halobs Hsendevs Hreceiveevs Hown_send Hown_recv"; last first.
  {
    iDestruct ("Hwp" with "Hsif Hsa' HB [$Hmfrag //] HIPs Hn Halobs [Hsendevs Hown_send]
                          [Hreceiveevs Hown_recv] Hobserved_send Hobserved_receive") as "Hwp".
    { iApply big_sepS_sep. iFrame "Hsendevs Hown_send". }
    { iApply big_sepS_sep. iFrame "Hreceiveevs Hown_recv". }
    iMod "Hwp". iModIntro. iFrame.
    iIntros (???) "% % % % % % (?& Hsi & Htr & % & Hauth) Hpost". iSplit; last first.
    { iIntros (?). iApply fupd_mask_intro_discard; done. }
    iIntros "!> ((?&?&?&%&?) &?) /=". iFrame. done. }
  iMod (socket_address_group_own_alloc_subseteq _ C (obs_send_sas ∪ obs_rec_sas) with "Hauth")
    as "[Hauth Hown_send_recv]"; [by set_solver|].
  iPoseProof (aneris_events_state_interp_init with "[$] [$] [$] [$] [$] [$]") as "$".
  simpl.
  rewrite Hmse gset_of_gmultiset_empty.
  iMod (socket_address_group_own_alloc_subseteq _ C C with "Hauth")
    as "[Hauth Hown]"; [by set_solver|].
  iMod (socket_address_group_own_alloc_subseteq _ C B with "Hauth")
    as "[Hauth HownB]"; [by set_solver|].
  iPoseProof (@aneris_state_interp_init _ _ dg IPs _ _ _ _ _
               with "[$Hmp] [//] [$Hh] [$Hs] [$Hms] [$Hauth] [$Hown] [$HownB] [$Hsif] [$HM] [$Hsa'] [$HIPsCtx] [$HPiu]") as "$"; eauto.
  simpl.
  iFrame "Hmfull Hsteps".
  done.
Qed.

Theorem adequacy1 `{anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)} IPs A B
        (lbls: gset string)
        (obs_send_sas obs_rec_sas : gset socket_address)
        s e ip σ φ :
  aneris_model_rel_finitary Mdl →
  wp_group_single_proto IPs A B lbls obs_send_sas obs_rec_sas s e ip φ →
  ip ∉ IPs →
  dom (state_ports_in_use σ) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ !! ip = Some ∅) →
  (∀ a, a ∈ A → ip_of_address a ∈ IPs) →
  state_heaps σ = {[ip:=∅]} →
  state_sockets σ = {[ip:=∅]} →
  state_ms σ = ∅ →
  adequate s (mkExpr ip e) σ (λ v _, φ v).
Proof.
  intros HMdlfin Hwp Hipdom Hpiiu Hip Hfixdom Hste Hsce Hmse.
  eapply (adequacy_groups _
                         (to_singletons A) (to_singletons B)
                         (to_singletons (A ∪ B ∪ obs_send_sas ∪ obs_rec_sas))
                         _
                         (to_singletons obs_send_sas) (to_singletons obs_rec_sas)
         ); eauto.
  { apply to_singletons_all_disjoint. }
  { apply to_singletons_is_ne. }
  { rewrite to_singletons_difference_comm. apply to_singletons_all_singleton. }
  { set_solver. }
  { set_solver. }
  { set_solver. }
  { set_solver. }
  iIntros (Mdl').
  iMod (Hwp Mdl') as (f) "Hwp".
  iModIntro.
  iExists (λ x, f (hd inhabitant (elements x))).
  iIntros "Hfix HA HB Hfrag HIP Hnode Hlbls Hsend Hrecv Hsend_obs Hrecv_obs".
  iApply ("Hwp" with "Hfix [HA] [HB] Hfrag HIP Hnode Hlbls [Hsend] [Hrecv] Hsend_obs Hrecv_obs").
  { iDestruct (big_sepS_to_singletons _
      (λ xs, xs ⤇* f (hd inhabitant (elements xs)))
      (λ x, x ⤇1 f x) with "[] HA") as "HA".
    { iIntros "!>" (x) "Hx".
      by rewrite (elements_singleton x). }
    iApply (big_sepS_mono with "HA").
    iIntros (x Hxin) "Hx". done. }
  { iDestruct (big_sepS_to_singletons _
      (λ xs, xs ⤳*[ bool_decide (xs ∈ to_singletons obs_send_sas),
                    bool_decide (xs ∈ to_singletons obs_rec_sas)] (∅, ∅))%I
      (λ x, x ⤳1[ bool_decide (x ∈ obs_send_sas),
                  bool_decide (x ∈ obs_rec_sas)] (∅, ∅))%I
                 with "[] HB") as "HB".
    { iIntros "!>" (x) "Hx".
      erewrite <-bool_decide_ext; last apply elem_of_to_singletons.
      erewrite <-(bool_decide_ext _ ({[x]} ∈ to_singletons obs_rec_sas)); last by apply elem_of_to_singletons.
      done. }
    done. }
  { iDestruct (big_sepS_to_singletons _
      (λ xs, sendon_evs_groups xs [])%I
      (λ x, sendon_evs x [])%I
                 with "[] Hsend") as "$".
    iIntros "!>" (x) "Hx". eauto. }
  { iDestruct (big_sepS_to_singletons _
      (λ xs, receiveon_evs_groups xs [])%I
      (λ x, receiveon_evs x [])%I
                 with "[] Hrecv") as "$".
    iIntros "!>" (x) "Hx". eauto. }
  intros sag sa Hsag Hsa.
  apply Hfixdom.
  assert (sag = {[sa]}) as ->.
  { pose proof (elem_of_to_singletons_inv A _ Hsag) as [sag' Hsag'].
    set_solver. }
  set_solver.
Qed.

Theorem adequacy `{anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)} IPs A B
        (lbls: gset string)
        (obs_send_sas obs_rec_sas : gset socket_address)
        s e ip σ φ :
  aneris_model_rel_finitary Mdl →
  (∀ `{anerisG Mdl Σ}, ⊢ |={⊤}=> ∃ (f : socket_address → socket_interp Σ),
     fixed A -∗
     ([∗ set] a ∈ A, a ⤇ (f a)) -∗
     ([∗ set] b ∈ B, b ⤳[bool_decide (b ∈ obs_send_sas), bool_decide (b ∈ obs_rec_sas)] (∅, ∅)) -∗
     frag_st Mdl.(model_state_initial) -∗
     ([∗ set] i ∈ IPs, free_ip i) -∗
     is_node ip -∗
     ([∗ set] lbl ∈ lbls, alloc_evs lbl []) -∗
     ([∗ set] sa ∈ obs_send_sas, sendon_evs sa []) -∗
     ([∗ set] sa ∈ obs_rec_sas, receiveon_evs sa []) -∗
     observed_send obs_send_sas -∗
     observed_receive obs_rec_sas ={⊤}=∗
     WP (mkExpr ip e) @ s; (ip,0); ⊤ {{v, ⌜φ v⌝ }}) →
  ip ∉ IPs →
  dom (state_ports_in_use σ) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ !! ip = Some ∅) →
  (∀ a, a ∈ A → ip_of_address a ∈ IPs) →
  state_heaps σ = {[ip:=∅]} →
  state_sockets σ = {[ip:=∅]} →
  state_ms σ = ∅ →
  adequate s (mkExpr ip e) σ (λ v _, φ v).
Proof.
  intros HMdlfin Hwp Hipdom Hpiiu Hip Hfixdom Hste Hsce Hmse.
  eapply (adequacy_groups _
                         (to_singletons A) (to_singletons B)
                         (to_singletons (A ∪ B ∪ obs_send_sas ∪ obs_rec_sas))
                         _
                         (to_singletons obs_send_sas) (to_singletons obs_rec_sas)
         ); eauto. 
  { apply to_singletons_all_disjoint. }
  { apply to_singletons_is_ne. }
  { rewrite to_singletons_difference_comm. apply to_singletons_all_singleton. }
  { set_solver. }
  { set_solver. }
  { set_solver. }
  { set_solver. }
  iIntros (Mdl').
  iMod (Hwp Mdl') as (f) "Hwp".
  iModIntro.
  iExists (λ x, from_singleton $ f (hd inhabitant (elements x))).
  iIntros "Hfix HA HB Hfrag HIP Hnode Hlbls Hsend Hrecv Hsend_obs Hrecv_obs".
  iApply ("Hwp" with "Hfix [HA] [HB] Hfrag HIP Hnode Hlbls [Hsend] [Hrecv] Hsend_obs Hrecv_obs").
  { iDestruct (big_sepS_to_singletons _
      (λ xs, xs ⤇* (from_singleton $ f (hd inhabitant (elements xs))))
      (λ x, x ⤇ f x) with "[] HA") as "HA".
    { iIntros "!>" (x) "Hx". by rewrite (elements_singleton x). }
    iApply (big_sepS_mono with "HA").
    iIntros (x Hxin) "Hx". done. }
  { iDestruct (big_sepS_to_singletons _
      (λ xs, xs ⤳*[ bool_decide (xs ∈ to_singletons obs_send_sas),
                   bool_decide (xs ∈ to_singletons obs_rec_sas)] (∅, ∅))%I
      (λ x, x ⤳[ bool_decide (x ∈ obs_send_sas),
                 bool_decide (x ∈ obs_rec_sas)] (∅, ∅))%I
                 with "[] HB") as "HB".
    { iIntros "!>" (x) "Hx".
      iSplit; [| by iApply big_sepS_empty ].
      erewrite <-bool_decide_ext; last apply elem_of_to_singletons.
      erewrite <-(bool_decide_ext _ ({[x]} ∈ to_singletons obs_rec_sas)); last by apply elem_of_to_singletons. done. }
    done. }
  { iDestruct (big_sepS_to_singletons _
      (λ xs, sendon_evs_groups xs [])%I
      (λ x, sendon_evs x [])%I
                 with "[] Hsend") as "$".
    iIntros "!>" (x) "Hx". eauto. }
  { iDestruct (big_sepS_to_singletons _
      (λ xs, receiveon_evs_groups xs [])%I
      (λ x, receiveon_evs x [])%I
                 with "[] Hrecv") as "$".
    iIntros "!>" (x) "Hx". eauto. }
  intros sag sa Hsag Hsa.
  apply Hfixdom.
  assert (sag = {[sa]}) as ->.
  { pose proof (elem_of_to_singletons_inv A _ Hsag) as [sag' Hsag'].
    set_solver. }
  set_solver.
Qed.

Definition safe e σ := @adequate aneris_lang NotStuck e σ (λ _ _, True).

Theorem adequacy_groups_safe `{anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)}
        IPs A B C lbls obs_send_sas obs_rec_sas e ip σ :
  all_disjoint C →
  set_Forall (λ sag, sag ≠ ∅) C →
  set_Forall is_singleton (C ∖ A) →
  A ⊆ C → B ⊆ C → obs_send_sas ⊆ C → obs_rec_sas ⊆ C →
  aneris_model_rel_finitary Mdl →
  wp_group_proto IPs A B lbls obs_send_sas obs_rec_sas NotStuck e ip (λ _, True) →
  ip ∉ IPs →
  dom (state_ports_in_use σ) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ !! ip = Some ∅) →
  (∀ sag sa, sag ∈ A → sa ∈ sag → ip_of_address sa ∈ IPs) →
  state_heaps σ = {[ip:=∅]} →
  state_sockets σ = {[ip:=∅]} →
  state_ms σ = ∅ →
  safe (mkExpr ip e) σ.
Proof. by apply adequacy_groups. Qed.

Theorem adequacy1_safe `{anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)}
        IPs A B lbls obs_send_sas obs_rec_sas e ip σ :
  aneris_model_rel_finitary Mdl →
  wp_group_single_proto IPs A B lbls obs_send_sas obs_rec_sas NotStuck e ip (λ _, True) →
  ip ∉ IPs →
  dom (state_ports_in_use σ) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ !! ip = Some ∅) →
  (∀ a, a ∈ A → ip_of_address a ∈ IPs) →
  state_heaps σ = {[ip:=∅]} →
  state_sockets σ = {[ip:=∅]} →
  state_ms σ = ∅ →
  safe (mkExpr ip e) σ.
Proof. by apply adequacy1. Qed.

Theorem adequacy_safe `{anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)}
        IPs A B lbls obs_send_sas obs_rec_sas e ip σ :
  aneris_model_rel_finitary Mdl →
  (∀ `{anerisG Mdl Σ}, ⊢ |={⊤}=> ∃ (f : socket_address → socket_interp Σ),
     fixed A -∗
     ([∗ set] a ∈ A, a ⤇ (f a)) -∗
     ([∗ set] b ∈ B, b ⤳[bool_decide (b ∈ obs_send_sas), bool_decide (b ∈ obs_rec_sas)] (∅, ∅)) -∗
     frag_st Mdl.(model_state_initial) -∗
     ([∗ set] i ∈ IPs, free_ip i) -∗
     is_node ip -∗
     ([∗ set] lbl ∈ lbls, alloc_evs lbl []) -∗
     ([∗ set] sa ∈ obs_send_sas, sendon_evs sa []) -∗
     ([∗ set] sa ∈ obs_rec_sas, receiveon_evs sa []) -∗
     observed_send obs_send_sas -∗
     observed_receive obs_rec_sas ={⊤}=∗
     WP (mkExpr ip e) @ (ip, 0) {{v, True }}) →
  ip ∉ IPs →
  dom (state_ports_in_use σ) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ !! ip = Some ∅) →
  (∀ a, a ∈ A → ip_of_address a ∈ IPs) →
  state_heaps σ = {[ip:=∅]} →
  state_sockets σ = {[ip:=∅]} →
  state_ms σ = ∅ →
  safe (mkExpr ip e) σ.
Proof. by apply adequacy. Qed.

Definition simulation_adequacy_with_trace_inv_groups `{!anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)}
           (s: stuckness)
           (IPs: gset ip_address)
           (lbls : gset string)
           (A B C obs_send_sas obs_rec_sas : gset socket_address_group)
           (ξ: execution_trace aneris_lang → auxiliary_trace (aneris_to_trace_model Mdl) → Prop)
           (φ: language.val aneris_lang → Prop)
           ip e1 σ1 :
  all_disjoint C →
  set_Forall (λ sag, sag ≠ ∅) C →
  set_Forall is_singleton (C ∖ A) →
  A ⊆ C → B ⊆ C → obs_send_sas ⊆ C → obs_rec_sas ⊆ C →
  rel_finitary (sim_rel ξ) ->
  (* The initial configuration satisfies certain properties *)
  ip ∉ IPs →
  dom (state_ports_in_use σ1) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ1 !! ip = Some ∅) →
  (∀ sag sa, sag ∈ A → sa ∈ sag → ip_of_address sa ∈ IPs) →
  state_heaps σ1 = {[ip:=∅]} →
  state_sockets σ1 = {[ip:=∅]} →
  state_ms σ1 = ∅ →
  (* A big implication, and we get back a Coq proposition *)
  (* For any proper Aneris resources *)
  (∀ `{!anerisG Mdl Σ},
      ⊢ |={⊤}=>
        (* There exists a trace invariant and a socket interpretation function *)
     ∃ (trace_inv : execution_trace aneris_lang → auxiliary_trace _ → iProp Σ)
       (Φ : language.val aneris_lang → iProp Σ)
       (f : socket_address_group → socket_interp Σ),
     (* Given resources reflecting initial configuration, we need to prove two goals *)
     fixed_groups A -∗ ([∗ set] a ∈ A, a ⤇* (f a)) -∗
     ([∗ set] b ∈ B, b ⤳*[bool_decide (b ∈ obs_send_sas), bool_decide (b ∈ obs_rec_sas)] (∅, ∅)) -∗
     ([∗ set] i ∈ IPs, free_ip i) -∗ is_node ip -∗
     ([∗ set] lbl ∈ lbls, alloc_evs lbl []) -∗
     ([∗ set] sa ∈ obs_send_sas, sendon_evs_groups sa []) -∗
     ([∗ set] sa ∈ obs_rec_sas, receiveon_evs_groups sa []) -∗
     observed_send_groups obs_send_sas -∗
     observed_receive_groups obs_rec_sas -∗
     frag_st Mdl.(model_state_initial) ={⊤}=∗
     (∀ v, Φ v -∗ ⌜φ v⌝) ∗
     WP (mkExpr ip e1) @ s; (ip,0); ⊤ {{ Φ }} ∗
     (∀ (ex : execution_trace aneris_lang) (atr : auxiliary_trace (aneris_to_trace_model Mdl)) c3,
         ⌜valid_system_trace ex atr⌝ -∗
         ⌜trace_starts_in ex ([mkExpr ip e1], σ1)⌝ -∗
         ⌜trace_starts_in atr Mdl.(model_state_initial)⌝ -∗
         ⌜trace_ends_in ex c3⌝ -∗
         ⌜∀ ex' atr' oζ ℓ, trace_contract ex oζ ex' → trace_contract atr ℓ atr' → ξ ex' atr'⌝ -∗
         ⌜∀ e2, s = NotStuck → e2 ∈ c3.1 → not_stuck e2 c3.2⌝ -∗
         state_interp ex atr -∗
         posts_of c3.1 (Φ :: (map (λ '(tnew, e), fork_post (locale_of tnew e)) (prefixes_from [mkExpr ip e1] (drop (length [mkExpr ip e1]) c3.1)))) -∗
         □ (state_interp ex atr ∗
           (∀ ex' atr' oζ ℓ, ⌜trace_contract ex oζ ex'⌝ → ⌜trace_contract atr ℓ atr'⌝ → trace_inv ex' atr')
            ={⊤}=∗ state_interp ex atr ∗ trace_inv ex atr) ∗
           ((∀ ex' atr' oζ ℓ, ⌜trace_contract ex oζ ex'⌝ → ⌜trace_contract atr ℓ atr'⌝ → trace_inv ex' atr')
     ={⊤, ∅}=∗ ⌜ξ ex atr⌝))) →
  (* The coinductive pure coq proposition given by adequacy *)
  (continued_simulation ξ (trace_singleton ([(mkExpr ip e1)], σ1))
                          (trace_singleton Mdl.(model_state_initial)) ∧
     adequate s (mkExpr ip e1) σ1 (λ v _, φ v)).
Proof.
  intros Hdisj Hne Hsingle HAle HBle Hsendle Hrecvle.
  intros Hsc Hips Hdom Hports Hsa Hheaps Hsockets Hms Hwp.
  epose proof (sim_and_adequacy_xi _ _ Σ s (sim_rel ξ) φ (mkExpr ip e1) σ1 Mdl.(model_state_initial) Hsc _)
    as [? ?] =>//.
  split; [|done].
  eapply continued_simulation_impl; [|done].
  by intros ? ? [? ?]. Unshelve.
  iIntros (?) "".
  iMod node_gnames_auth_init as (γmp) "Hmp".
  iMod saved_si_init as (γsi) "[Hsi Hsi']".
  iMod (fixed_address_groups_init A) as (γsif) "#Hsif".
  iMod (free_ips_init IPs) as (γips) "[HIPsCtx HIPs]".
  iMod free_ports_auth_init as (γpiu) "HPiu".
  iMod (fixed_address_groups_init obs_send_sas) as
      (γobserved_send) "#Hobserved_send".
  iMod (fixed_address_groups_init obs_rec_sas) as
      (γobserved_receive) "#Hobserved_receive".
  iMod (socket_address_group_ctx_init) as (γC) "Hauth"; [done|].
  iMod (socket_address_group_own_alloc_subseteq _ C A with "Hauth") as
      "[Hauth HownA]"; [done|].
  iDestruct (socket_address_group_own_big_sepS with "HownA") as "HownAS".
  iMod (socket_address_group_own_alloc_subseteq _ C B with "Hauth") as
      "[Hauth HownB]"; [done|].
  iDestruct (socket_address_group_own_big_sepS with "HownB") as "HownBS".
  iMod (messages_ctx_init B _ _ _ _ with "HownBS Hobserved_send Hobserved_receive" ) as (γms) "[Hms HB]".
  iMod steps_init as (γsteps) "[Hsteps _]".
  iMod (model_init Mdl.(model_state_initial)) as (γm) "[Hmfull Hmfrag]".
  assert (rtc Mdl Mdl.(model_state_initial) Mdl.(model_state_initial)).
  { constructor. }
  iMod (alloc_evs_init lbls) as (γalevs) "[Halobctx Halobs]".
  iMod (sendreceive_evs_init obs_send_sas) as
      (γsendevs) "[Hsendevsctx Hsendevs]".
  iMod (sendreceive_evs_init obs_rec_sas) as
      (γreceiveevs) "[Hreceiveevsctx Hreceiveevs]".
  set (dg :=
         {|
           aneris_node_gnames_name := γmp;
           aneris_si_name := γsi;
           aneris_socket_address_group_name := γC;
           aneris_fixed_socket_address_groups_name := γsif;
           aneris_freeips_name := γips;
           aneris_freeports_name := γpiu;
           aneris_messages_name := γms;
           aneris_model_name := γm;
           aneris_steps_name := γsteps;
           aneris_allocEVS_name := γalevs;
           aneris_sendonEVS_name := γsendevs;
           aneris_receiveonEVS_name := γreceiveevs;
           aneris_observed_send_name := γobserved_send;
           aneris_observed_recv_name := γobserved_receive;
         |}).
  iMod (Hwp dg) as "Hwp". iDestruct "Hwp" as (trace_inv Φ f) "Himpl".
  iMod (saved_si_update A with "[$Hsi $Hsi']") as (M HMfs) "[HM #Hsa]".
  assert (dom M = A) as Hdmsi.
  { apply set_eq => ?.
    split; intros ?%elem_of_elements;
      apply elem_of_elements; [by rewrite -HMfs|].
    by rewrite HMfs. }
  iAssert ([∗ set] s ∈ A, s ⤇* f s)%I as "#Hsa'".
  { rewrite -Hdmsi -!big_sepM_dom.
    iDestruct (big_sepM_sep with "[$HownAS $Hsa]") as "#Hsa'".
    iApply (big_sepM_impl with "[$Hsa']"); simpl; auto.
    iIntros "!>" (? ? Hx) "[? ?]"; iExists _.
    rewrite /saved_si. iFrame. }
  iMod (node_ctx_init ∅ ∅) as (γn) "[Hh Hs]".
  iMod (node_gnames_alloc γn _ ip with "[$]") as "[Hmp #Hγn]"; [done|].
  iAssert (is_node ip) as "Hn".
  { iExists _. eauto. }
  iMod (socket_address_group_own_alloc_subseteq _ C obs_send_sas with "Hauth")
    as "[Hauth Hown_send]"; [done|].
  iDestruct (socket_address_group_own_big_sepS with "Hown_send") as "Hown_send".
  iMod (socket_address_group_own_alloc_subseteq _ C obs_rec_sas with "Hauth")
    as "[Hauth Hown_recv]"; [done|].
  iDestruct (socket_address_group_own_big_sepS with "Hown_recv") as "Hown_recv".
  iMod ("Himpl" with "[$] [$] [$] [$] [$] [$] [Hsendevs Hown_send]
[Hreceiveevs Hown_recv] [$] [$] [$Hmfrag //]") as "(HΦ & Hwp & Himpl)".
  { iApply big_sepS_sep. iFrame "Hsendevs Hown_send". }
  { iApply big_sepS_sep. iFrame "Hreceiveevs Hown_recv". }
  iMod (socket_address_group_own_alloc_subseteq _ C (obs_send_sas ∪ obs_rec_sas) with "Hauth")
    as "[Hauth Hown_send_recv]"; [by set_solver|].
  iMod (socket_address_group_own_alloc_subseteq _ C C with "Hauth")
    as "[Hauth Hown]"; [by set_solver|].
  iMod (socket_address_group_own_alloc_subseteq _ C B with "Hauth")
    as "[Hauth HownB]"; [by set_solver|].
  iModIntro. iExists state_interp, trace_inv, Φ, fork_post.
  iSplitL ""; first by iApply config_wp_correct.
  iFrame "Hwp HΦ".
  iPoseProof (aneris_events_state_interp_init with "[$] [$] [$] [$] [$] [$]") as "$".
  iPoseProof (@aneris_state_interp_init _ _ dg IPs _ _ _ _ _
                with "[$Hmp] [//] [$Hh] [$Hs] [$Hms] [$Hauth] [$Hown] [$HownB] [$Hsif] [$HM] [$Hsa'] [$HIPsCtx] [$HPiu]") as "Hsi"; eauto; [].
  rewrite /= Hms gset_of_gmultiset_empty.
  iFrame. iSplit; [done|].
  iIntros (??????? Hcontr ?) "(Hev & Hsi & Hauth & % & Hsteps) Hpost".
  iDestruct ("Himpl" with "[//] [//] [//] [//] [] [//] [$Hev $Hsi $Hauth $Hsteps //] [$Hpost]") as "[$ Hrel]".
  { iPureIntro. intros ??????. by eapply Hcontr. }
  iIntros "Hct". iMod ("Hrel" with "Hct") as "%".
  iModIntro. eauto.
Qed.

Definition simulation_adequacy1_with_trace_inv Σ Mdl `{!anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)}
           (s: stuckness)
           (IPs: gset ip_address)
           (lbls : gset string)
           (A B obs_send_sas obs_rec_sas : gset socket_address)
           (ξ: execution_trace aneris_lang → auxiliary_trace (aneris_to_trace_model Mdl) → Prop)
           (φ: language.val aneris_lang → Prop)
           ip e1 σ1 :
  (* The model has finite branching *)
  rel_finitary (sim_rel ξ) →
  (* The initial configuration satisfies certain properties *)
  ip ∉ IPs →
  dom (state_ports_in_use σ1) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ1 !! ip = Some ∅) →
  (∀ a, a ∈ A → ip_of_address a ∈ IPs) →
  state_heaps σ1 = {[ip:=∅]} →
  state_sockets σ1 = {[ip:=∅]} →
  state_ms σ1 = ∅ →
  (* A big implication, and we get back a Coq proposition *)
  (* For any proper Aneris resources *)
  (∀ `{!anerisG Mdl Σ},
      ⊢ |={⊤}=>
        (* There exists a trace invariant, a postcondition and a socket interpretation function *)
     ∃ (trace_inv : execution_trace aneris_lang → auxiliary_trace _ → iProp Σ)
       (Φ : language.val aneris_lang → iProp Σ)
       (f : socket_address → socket_interp Σ),
       (* Given resources reflecting initial configuration, we need to prove two goals *)
       fixed A -∗ ([∗ set] a ∈ A, a ⤇1 (f a)) -∗
       ([∗ set] b ∈ B, b ⤳1[bool_decide (b ∈ obs_send_sas), bool_decide (b ∈ obs_rec_sas)] (∅, ∅)) -∗
       ([∗ set] i ∈ IPs, free_ip i) -∗ is_node ip -∗
       ([∗ set] lbl ∈ lbls, alloc_evs lbl []) -∗
       ([∗ set] sa ∈ obs_send_sas, sendon_evs sa []) -∗
       ([∗ set] sa ∈ obs_rec_sas, receiveon_evs sa []) -∗
       observed_send obs_send_sas -∗
       observed_receive obs_rec_sas -∗
       frag_st Mdl.(model_state_initial) ={⊤}=∗
       (∀ v, Φ v -∗ ⌜φ v⌝) ∗
       WP (mkExpr ip e1) @ s; (ip, 0); ⊤ {{ Φ }} ∗
       (∀ (ex : execution_trace aneris_lang) (atr : auxiliary_trace (aneris_to_trace_model Mdl)) c3,
           ⌜valid_system_trace ex atr⌝ -∗
           ⌜trace_starts_in ex ([mkExpr ip e1], σ1)⌝ -∗
           ⌜trace_starts_in atr Mdl.(model_state_initial)⌝ -∗
           ⌜trace_ends_in ex c3⌝ -∗
           ⌜∀ ex' atr' oζ ℓ, trace_contract ex oζ ex' → trace_contract atr ℓ atr' → ξ ex' atr'⌝ -∗
      ⌜∀ e2, s = NotStuck → e2 ∈ c3.1 → not_stuck e2 c3.2⌝ -∗
      state_interp ex atr -∗
      posts_of c3.1 (Φ :: (map (λ '(tnew, e), fork_post (locale_of tnew e)) (prefixes_from [mkExpr ip e1] (drop (length [mkExpr ip e1]) c3.1)))) -∗
      □ (state_interp ex atr ∗
          (∀ ex' atr' oζ ℓ, ⌜trace_contract ex oζ ex'⌝ → ⌜trace_contract atr ℓ atr'⌝ → trace_inv ex' atr')
         ={⊤}=∗ state_interp ex atr ∗ trace_inv ex atr) ∗
      ((∀ ex' atr' oζ ℓ,
           ⌜trace_contract ex oζ ex'⌝ → ⌜trace_contract atr ℓ atr'⌝ → trace_inv ex' atr')
       ={⊤, ∅}=∗ ⌜ξ ex atr⌝))) →
  (* The coinductive pure coq proposition given by adequacy *)
  (continued_simulation ξ (trace_singleton ([(mkExpr ip e1)], σ1))
                          (trace_singleton Mdl.(model_state_initial)) ∧
     adequate s (mkExpr ip e1) σ1 (λ v _, φ v)).
Proof.
  intros Hsc Hips Hdom Hports Hsa Hheaps Hsockets Hms Hwp.
  eapply (simulation_adequacy_with_trace_inv_groups _ _ _
                         (to_singletons A) (to_singletons B)
                         (to_singletons (A ∪ B ∪ obs_send_sas ∪ obs_rec_sas))
                         (to_singletons obs_send_sas) (to_singletons obs_rec_sas)); eauto.
  { apply to_singletons_all_disjoint. }
  { apply to_singletons_is_ne. }
  { rewrite to_singletons_difference_comm. apply to_singletons_all_singleton. }
  { set_solver. }
  { set_solver. }
  { set_solver. }
  { set_solver. }
  { intros sag sa Hsag Hsa'.
    apply Hsa.
    assert (sag = {[sa]}) as ->.
    { pose proof (elem_of_to_singletons_inv A _ Hsag) as [sag' Hsag'].
      set_solver. }
    by rewrite elem_of_to_singletons. }
  iIntros (Mdl').
  iMod (Hwp Mdl') as (trace_inv Φ f) "Hwp".
  iModIntro.
  iExists trace_inv, Φ, (λ x, f (hd inhabitant (elements x))).
  iIntros "Hfix HA HB HIP Hnode Hlbls Hsend Hrecv Hsend_obs Hrecv_obs Hfrag".
  iApply ("Hwp" with "Hfix [HA] [HB] HIP Hnode Hlbls [Hsend] [Hrecv] Hsend_obs Hrecv_obs Hfrag").
  { iDestruct (big_sepS_to_singletons _
      (λ xs, xs ⤇* f (hd inhabitant (elements xs)))
      (λ x, x ⤇1 f x) with "[] HA") as "HA".
    { iIntros "!>" (x) "Hx". by rewrite (elements_singleton x). }
    iApply (big_sepS_mono with "HA").
    iIntros (x Hxin) "Hx". done. }
  { iDestruct (big_sepS_to_singletons _
      (λ xs, xs ⤳*[ bool_decide (xs ∈ to_singletons obs_send_sas),
                    bool_decide (xs ∈ to_singletons obs_rec_sas)] (∅, ∅))%I
      (λ x, x ⤳1[ bool_decide (x ∈ obs_send_sas),
                  bool_decide (x ∈ obs_rec_sas)] (∅, ∅))%I
                 with "[] HB") as "HB".
    { iIntros "!>" (x) "Hx".
      erewrite <-bool_decide_ext; last apply elem_of_to_singletons.
      erewrite <-(bool_decide_ext _ ({[x]} ∈ to_singletons obs_rec_sas)); last by apply elem_of_to_singletons.
      done. }
    done. }
  { iDestruct (big_sepS_to_singletons _
      (λ xs, sendon_evs_groups xs [])%I
      (λ x, sendon_evs x [])%I
                 with "[] Hsend") as "$".
    iIntros "!>" (x) "Hx". eauto. }
  { iDestruct (big_sepS_to_singletons _
      (λ xs, receiveon_evs_groups xs [])%I
      (λ x, receiveon_evs x [])%I
                 with "[] Hrecv") as "$".
    iIntros "!>" (x) "Hx". eauto. }
Qed.

Definition simulation_adequacy_with_trace_inv `{!anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)}
           (s: stuckness)
           (IPs: gset ip_address)
           (lbls : gset string)
           (A B obs_send_sas obs_rec_sas : gset socket_address)
           (ξ: execution_trace aneris_lang → auxiliary_trace (aneris_to_trace_model Mdl) → Prop)
           (φ: language.val aneris_lang → Prop)
           ip e1 σ1 :
  (* The model has finite branching *)
  rel_finitary (sim_rel ξ) ->
  (* The initial configuration satisfies certain properties *)
  ip ∉ IPs →
  dom (state_ports_in_use σ1) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ1 !! ip = Some ∅) →
  (∀ a, a ∈ A → ip_of_address a ∈ IPs) →
  state_heaps σ1 = {[ip:=∅]} →
  state_sockets σ1 = {[ip:=∅]} →
  state_ms σ1 = ∅ →
  (* A big implication, and we get back a Coq proposition *)
  (* For any proper Aneris resources *)
  (∀ `{!anerisG Mdl Σ},
      ⊢ |={⊤}=>
        (* There exists a trace invariant, a postcondition and a socket interpretation function *)
     ∃ (trace_inv : execution_trace aneris_lang → auxiliary_trace _ → iProp Σ)
       (Φ : language.val aneris_lang → iProp Σ)
       (f : socket_address → socket_interp Σ),
       (* Given resources reflecting initial configuration, we need to prove two goals *)
       fixed A -∗ ([∗ set] a ∈ A, a ⤇ (f a)) -∗
       ([∗ set] b ∈ B, b ⤳[bool_decide (b ∈ obs_send_sas), bool_decide (b ∈ obs_rec_sas)] (∅, ∅)) -∗
       ([∗ set] i ∈ IPs, free_ip i) -∗ is_node ip -∗
       ([∗ set] lbl ∈ lbls, alloc_evs lbl []) -∗
       ([∗ set] sa ∈ obs_send_sas, sendon_evs sa []) -∗
       ([∗ set] sa ∈ obs_rec_sas, receiveon_evs sa []) -∗
       observed_send obs_send_sas -∗
       observed_receive obs_rec_sas -∗
       frag_st Mdl.(model_state_initial) ={⊤}=∗
       (∀ v, Φ v -∗ ⌜φ v⌝) ∗
       WP (mkExpr ip e1) @ s; (ip, 0); ⊤ {{ Φ }} ∗
       (∀ (ex : execution_trace aneris_lang) (atr : auxiliary_trace (aneris_to_trace_model Mdl)) c3,
           ⌜valid_system_trace ex atr⌝ -∗
           ⌜trace_starts_in ex ([mkExpr ip e1], σ1)⌝ -∗
           ⌜trace_starts_in atr Mdl.(model_state_initial)⌝ -∗
           ⌜trace_ends_in ex c3⌝ -∗
           ⌜∀ ex' atr' oζ ℓ, trace_contract ex oζ ex' → trace_contract atr ℓ atr' → ξ ex' atr'⌝ -∗
      ⌜∀ e2, s = NotStuck → e2 ∈ c3.1 → not_stuck e2 c3.2⌝ -∗
      state_interp ex atr -∗
      posts_of c3.1 (Φ :: (map (λ '(tnew, e), fork_post (locale_of tnew e)) (prefixes_from [mkExpr ip e1] (drop (length [mkExpr ip e1]) c3.1)))) -∗
      □ (state_interp ex atr ∗
         (∀ ex' atr' oζ ℓ, ⌜trace_contract ex oζ ex'⌝ → ⌜trace_contract atr ℓ atr'⌝ → trace_inv ex' atr')
          ={⊤}=∗ state_interp ex atr ∗ trace_inv ex atr) ∗
      ((∀ ex' atr' oζ ℓ,
          ⌜trace_contract ex oζ ex'⌝ → ⌜trace_contract atr ℓ atr'⌝ → trace_inv ex' atr')
       ={⊤, ∅}=∗ ⌜ξ ex atr⌝))) →
  (* The coinductive pure coq proposition given by adequacy *)
  (continued_simulation ξ (trace_singleton ([(mkExpr ip e1)], σ1))
                          (trace_singleton Mdl.(model_state_initial)) ∧
   adequate s (mkExpr ip e1) σ1 (λ v _, φ v)).
Proof.
  intros Hsc Hips Hdom Hports Hsa Hheaps Hsockets Hms Hwp.
  eapply (simulation_adequacy_with_trace_inv_groups _ _ _
                         (to_singletons A) (to_singletons B)
                         (to_singletons (A ∪ B ∪ obs_send_sas ∪ obs_rec_sas))
                         (to_singletons obs_send_sas) (to_singletons obs_rec_sas)
         ); eauto.
  { apply to_singletons_all_disjoint. }
  { apply to_singletons_is_ne. }
  { rewrite to_singletons_difference_comm. apply to_singletons_all_singleton. }
  { set_solver. }
  { set_solver. }
  { set_solver. }
  { set_solver. }
  { intros sag sa Hsag Hsa'.
    apply Hsa.
    assert (sag = {[sa]}) as ->.
    { pose proof (elem_of_to_singletons_inv A _ Hsag) as [sag' Hsag'].
      set_solver. }
    by rewrite elem_of_to_singletons. }
  iIntros (Mdl').
  iMod (Hwp Mdl') as (trace_inv Φ f) "Hwp".
  iModIntro.
  iExists trace_inv, Φ, (λ x, from_singleton $ f (hd inhabitant (elements x))).
  iIntros "Hfix HA HB HIP Hnode Hlbls Hsend Hrecv Hsend_obs Hrecv_obs Hfrag".
  iApply ("Hwp" with "Hfix [HA] [HB] HIP Hnode Hlbls [Hsend] [Hrecv] Hsend_obs Hrecv_obs Hfrag").
  { iDestruct (big_sepS_to_singletons _
      (λ xs, xs ⤇* (from_singleton $ f (hd inhabitant (elements xs))))
      (λ x, x ⤇ f x) with "[] HA") as "HA".
    { iIntros "!>" (x) "Hx". by rewrite (elements_singleton x). }
    iApply (big_sepS_mono with "HA").
    iIntros (x Hxin) "Hx". done. }
  { iDestruct (big_sepS_to_singletons _
      (λ xs, xs ⤳*[ bool_decide (xs ∈ to_singletons obs_send_sas),
                    bool_decide (xs ∈ to_singletons obs_rec_sas)] (∅, ∅))%I
      (λ x, x ⤳[ bool_decide (x ∈ obs_send_sas),
                 bool_decide (x ∈ obs_rec_sas)] (∅, ∅))%I
                 with "[] HB") as "HB".
    { iIntros "!>" (x) "Hx".
      iSplit; [|by iApply big_sepS_empty].
      erewrite <-bool_decide_ext; last apply elem_of_to_singletons.
      erewrite <-(bool_decide_ext _ ({[x]} ∈ to_singletons obs_rec_sas)); last by apply elem_of_to_singletons.
      done. }
    done. }
  { iDestruct (big_sepS_to_singletons _
      (λ x, sendon_evs_groups x [])%I
      (λ x, sendon_evs x [])%I
                 with "[] Hsend") as "$".
    iIntros "!>" (x) "Hx". eauto. }
  { iDestruct (big_sepS_to_singletons _
      (λ x, receiveon_evs_groups x [])%I
      (λ x, receiveon_evs x [])%I
                 with "[] Hrecv") as "$".
    iIntros "!>" (x) "Hx". eauto. }
Qed.

Definition simulation_adequacy_groups Σ Mdl `{!anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)}
           (s: stuckness)
           (IPs: gset ip_address)
           (lbls : gset string)
           (A B C obs_send_sas obs_rec_sas : gset socket_address_group)
           (ξ: execution_trace aneris_lang → auxiliary_trace (aneris_to_trace_model Mdl) → Prop)
           ip e1 σ1 :
  all_disjoint C →
  set_Forall (λ sag, sag ≠ ∅) C →
  set_Forall is_singleton (C ∖ A) →
  A ⊆ C → B ⊆ C → obs_send_sas ⊆ C → obs_rec_sas ⊆ C →
  (* The model has finite branching *)
  rel_finitary (sim_rel ξ) →
  (* The initial configuration satisfies certain properties *)
  ip ∉ IPs →
  dom (state_ports_in_use σ1) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ1 !! ip = Some ∅) →
  (∀ sag sa, sag ∈ A → sa ∈ sag → ip_of_address sa ∈ IPs) →
  state_heaps σ1 = {[ip:=∅]} →
  state_sockets σ1 = {[ip:=∅]} →
  state_ms σ1 = ∅ →
  (* A big implication, and we get back a Coq proposition *)
  (* For any proper Aneris resources *)
  (∀ `{!anerisG Mdl Σ},
      ⊢ |={⊤}=>
        (* There exists a postcondition and a socket interpretation function *)
     ∃ (Φ : language.val aneris_lang → iProp Σ)
       (f : socket_address_group → socket_interp Σ),
     (* Given resources reflecting initial configuration, we need *)
     (* to prove two goals *)
       fixed_groups A -∗ ([∗ set] a ∈ A, a ⤇* (f a)) -∗
       ([∗ set] b ∈ B, b ⤳*[bool_decide (b ∈ obs_send_sas), bool_decide (b ∈ obs_rec_sas)] (∅, ∅)) -∗
       ([∗ set] i ∈ IPs, free_ip i) -∗ is_node ip -∗
       ([∗ set] lbl ∈ lbls, alloc_evs lbl []) -∗
       ([∗ set] sa ∈ obs_send_sas, sendon_evs_groups sa []) -∗
       ([∗ set] sa ∈ obs_rec_sas, receiveon_evs_groups sa []) -∗
       observed_send_groups obs_send_sas -∗
       observed_receive_groups obs_rec_sas -∗
       frag_st Mdl.(model_state_initial) ={⊤}=∗
       WP (mkExpr ip e1) @ s; (ip,0); ⊤ {{ Φ }} ∗
       (∀ (ex : execution_trace aneris_lang) (atr : auxiliary_trace (aneris_to_trace_model Mdl)) c3,
         ⌜valid_system_trace ex atr⌝ -∗
         ⌜trace_starts_in ex ([mkExpr ip e1], σ1)⌝ -∗
         ⌜trace_starts_in atr Mdl.(model_state_initial)⌝ -∗
         ⌜trace_ends_in ex c3⌝ -∗
         ⌜∀ ex' atr' oζ ℓ, trace_contract ex oζ ex' → trace_contract atr ℓ atr' → ξ ex' atr'⌝ -∗
         ⌜∀ e2, s = NotStuck → e2 ∈ c3.1 → not_stuck e2 c3.2⌝ -∗
         state_interp ex atr -∗
         posts_of c3.1 (Φ :: (map (λ '(tnew, e), fork_post (locale_of tnew e)) (prefixes_from [mkExpr ip e1] (drop (length [mkExpr ip e1]) c3.1)))) -∗
         |={⊤, ∅}=> ⌜ξ ex atr⌝)) →
  (* The coinductive pure coq proposition given by adequacy *)
  continued_simulation
    ξ
    (trace_singleton ([(mkExpr ip e1)], σ1))
    (trace_singleton Mdl.(model_state_initial)).
Proof.
  intros Hdisj Hne Hsingle HAle HBle Hsendle Hrecvle.
  intros Hsc Hips Hdom Hports Hsa Hheaps Hsockets Hms Hwp.
  eapply (simulation_adequacy_with_trace_inv_groups
          _ _ _ A B C obs_send_sas obs_rec_sas ξ (λ _, True)) =>//.
  iIntros (?) "".
  iMod Hwp as (Φ f) "Hwp".
  iModIntro.
  iExists (λ _ _, True)%I, Φ, f.
  iIntros "? ? ? ? ? ? ? ? ? ? ?".
  iMod ("Hwp" with "[$] [$] [$] [$] [$] [$] [$] [$] [$] [$] [$]") as "[$ Hstep]".
  iModIntro.
  iSplitR; [eauto|].
  iIntros (ex atr c3 ? ? ? ? ? ?) "HSI Hposts".
  iSplit; last first.
  { iIntros "_". iApply ("Hstep" with "[] [] [] [] [] [] HSI"); auto. }
  iModIntro; iIntros "[$ _]"; done.
Qed.

Definition simulation_adequacy1 Σ Mdl `{!anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)}
           (s: stuckness)
           (IPs: gset ip_address)
           (lbls : gset string)
           (A B obs_send_sas obs_rec_sas : gset socket_address)
           (ξ: execution_trace aneris_lang → auxiliary_trace (aneris_to_trace_model Mdl) → Prop)
           ip e1 σ1 :
  (* The model has finite branching *)
  rel_finitary (sim_rel ξ) →
  (* The initial configuration satisfies certain properties *)
  ip ∉ IPs →
  dom (state_ports_in_use σ1) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ1 !! ip = Some ∅) →
  (∀ a, a ∈ A → ip_of_address a ∈ IPs) →
  state_heaps σ1 = {[ip:=∅]} →
  state_sockets σ1 = {[ip:=∅]} →
  state_ms σ1 = ∅ →
  (* A big implication, and we get back a Coq proposition *)
  (* For any proper Aneris resources *)
  (∀ `{!anerisG Mdl Σ},
     ⊢ |={⊤}=>
        (* There exists a postcondition and a socket interpretation function *)
     ∃ (Φ : language.val aneris_lang → iProp Σ)
       (f : socket_address → socket_interp Σ),
     (* Given resources reflecting initial configuration, we need *)
     (* to prove two goals *)
     fixed A -∗ ([∗ set] a ∈ A, a ⤇1 (f a)) -∗
     ([∗ set] b ∈ B, b ⤳1[bool_decide (b ∈ obs_send_sas), bool_decide (b ∈ obs_rec_sas)] (∅, ∅)) -∗
     ([∗ set] i ∈ IPs, free_ip i) -∗ is_node ip -∗
     ([∗ set] lbl ∈ lbls, alloc_evs lbl []) -∗
     ([∗ set] sa ∈ obs_send_sas, sendon_evs sa []) -∗
     ([∗ set] sa ∈ obs_rec_sas, receiveon_evs sa []) -∗
     observed_send obs_send_sas -∗
     observed_receive obs_rec_sas -∗
     frag_st Mdl.(model_state_initial) ={⊤}=∗
     WP (mkExpr ip e1) @ s; (ip,0); ⊤ {{ Φ }} ∗
     (∀ (ex : execution_trace aneris_lang) (atr : auxiliary_trace (aneris_to_trace_model Mdl)) c3,
       ⌜valid_system_trace ex atr⌝ -∗
       ⌜trace_starts_in ex ([mkExpr ip e1], σ1)⌝ -∗
       ⌜trace_starts_in atr Mdl.(model_state_initial)⌝ -∗
       ⌜trace_ends_in ex c3⌝ -∗
       ⌜∀ ex' atr' oζ ℓ, trace_contract ex oζ ex' → trace_contract atr ℓ atr' → ξ ex' atr'⌝ -∗
       ⌜∀ e2, s = NotStuck → e2 ∈ c3.1 → not_stuck e2 c3.2⌝ -∗
       state_interp ex atr -∗
       posts_of c3.1 (Φ :: (map (λ '(tnew, e), fork_post (locale_of tnew e)) (prefixes_from [mkExpr ip e1] (drop (length [mkExpr ip e1]) c3.1)))) -∗
       |={⊤, ∅}=> ⌜ξ ex atr⌝)) →
  (* The coinductive pure coq proposition given by adequacy *)
  continued_simulation
    ξ
    (trace_singleton ([(mkExpr ip e1)], σ1))
    (trace_singleton Mdl.(model_state_initial)).
Proof.
  intros Hsc Hips Hdom Hports Hsa Hheaps Hsockets Hms Hwp.
  eapply (simulation_adequacy1_with_trace_inv
          _ _ _ _ _ A B obs_send_sas obs_rec_sas ξ (λ _, True))=>//.
  iIntros (?) "".
  iMod Hwp as (Φ f) "Hwp".
  iModIntro.
  iExists (λ _ _, True)%I, Φ, f.
  iIntros "? ? ? ? ? ? ? ? ? ? ?".
  iMod ("Hwp" with "[$] [$] [$] [$] [$] [$] [$] [$] [$] [$] [$]") as "[$ Hstep]".
  iModIntro.
  iSplitR; [eauto|].
  iIntros (ex atr c3 ? ? ? ? ? ? ) "HSI Hposts".
  iSplit; last first.
  { iIntros "_". iApply ("Hstep" with "[] [] [] [] [] [] HSI"); auto. }
  iModIntro; iIntros "[$ _]"; done.
Qed.

Definition simulation_adequacy Σ Mdl `{!anerisPreG Σ Mdl} `{EqDecision (aneris_to_trace_model Mdl)}
           (s: stuckness)
           (IPs: gset ip_address)
           (lbls : gset string)
           (A B obs_send_sas obs_rec_sas : gset socket_address)
           (φ : language.val aneris_lang → Prop)
           (ξ: execution_trace aneris_lang → auxiliary_trace (aneris_to_trace_model Mdl) → Prop)
           ip e1 σ1 :
  (* The model has finite branching *)
  rel_finitary (sim_rel ξ) →
  (* The initial configuration satisfies certain properties *)
  ip ∉ IPs →
  dom (state_ports_in_use σ1) = IPs →
  (∀ ip, ip ∈ IPs → state_ports_in_use σ1 !! ip = Some ∅) →
  (∀ a, a ∈ A → ip_of_address a ∈ IPs) →
  state_heaps σ1 = {[ip:=∅]} →
  state_sockets σ1 = {[ip:=∅]} →
  state_ms σ1 = ∅ →
  (* A big implication, and we get back a Coq proposition *)
  (* For any proper Aneris resources *)
  (∀ `{!anerisG Mdl Σ},
     ⊢ |={⊤}=>
     (* There exists a postcondition and a socket interpretation function *)
     ∃ Φ (f : socket_address → socket_interp Σ),
     (* Given resources reflecting initial configuration, we need *)
     (* to prove two goals *)
     fixed A -∗ ([∗ set] a ∈ A, a ⤇ (f a)) -∗
     ([∗ set] b ∈ B, b ⤳[bool_decide (b ∈ obs_send_sas), bool_decide (b ∈ obs_rec_sas)] (∅, ∅)) -∗
     ([∗ set] i ∈ IPs, free_ip i) -∗ is_node ip -∗
     ([∗ set] lbl ∈ lbls, alloc_evs lbl []) -∗
     ([∗ set] sa ∈ obs_send_sas, sendon_evs sa []) -∗
     ([∗ set] sa ∈ obs_rec_sas, receiveon_evs sa []) -∗
     observed_send obs_send_sas -∗
     observed_receive obs_rec_sas -∗
     frag_st Mdl.(model_state_initial) ={⊤}=∗
     (∀ v, Φ v -∗ ⌜φ v⌝) ∗
     WP (mkExpr ip e1) @ s; (ip,0); ⊤ {{ Φ }} ∗
     (∀ (ex : execution_trace aneris_lang) (atr : auxiliary_trace (aneris_to_trace_model Mdl)) c3,
       ⌜valid_system_trace ex atr⌝ -∗
       ⌜trace_starts_in ex ([mkExpr ip e1], σ1)⌝ -∗
       ⌜trace_starts_in atr Mdl.(model_state_initial)⌝ -∗
       ⌜trace_ends_in ex c3⌝ -∗
       ⌜∀ ex' atr' oζ ℓ, trace_contract ex oζ ex' → trace_contract atr ℓ atr' → ξ ex' atr'⌝ -∗
       ⌜∀ e2, s = NotStuck → e2 ∈ c3.1 → not_stuck e2 c3.2⌝ -∗
       state_interp ex atr -∗
       posts_of c3.1 (Φ :: (map (λ '(tnew, e), fork_post (locale_of tnew e)) (prefixes_from [mkExpr ip e1] (drop (length [mkExpr ip e1]) c3.1)))) -∗
       |={⊤, ∅}=> ⌜ξ ex atr⌝)) →
  (* The coinductive pure coq proposition given by adequacy *)
  (continued_simulation
    ξ
    (trace_singleton ([(mkExpr ip e1)], σ1))
    (trace_singleton Mdl.(model_state_initial)) ∧
     adequate s (mkExpr ip e1) σ1 (λ v _, φ v)).
Proof.
  intros Hsc Hips Hdom Hports Hsa Hheaps Hsockets Hms Hwp.
  eapply (simulation_adequacy_with_trace_inv
          _ _ _ A B obs_send_sas obs_rec_sas)=>//.
  iIntros (?) "".
  iMod Hwp as (Φ f) "Hwp".
  iModIntro.
  iExists (λ _ _, True)%I, Φ, f.
  iIntros "? ? ? ? ? ? ? ? ? ? ?".
  iMod ("Hwp" with "[$] [$] [$] [$] [$] [$] [$] [$] [$] [$] [$]") as "($ & $ & Hstep)".
  iModIntro.
  iIntros (ex atr c3 ? ? ? ? ? ?) "HSI Hposts".
  iSplit; last first.
  { iIntros "_". iApply ("Hstep" with "[] [] [] [] [] [] HSI"); auto. }
  iModIntro; iIntros "[$ _]"; done.
Qed.
