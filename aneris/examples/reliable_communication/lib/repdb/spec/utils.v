From iris.proofmode Require Import proofmode.
From aneris.examples.reliable_communication.lib.repdb.spec
     Require Import resources stdpp_utils events.

Section with_Σ.
  Context `{!anerisG Mdl Σ, TM : !DB_time, DB : !DB_params,
            !DB_events, !DB_resources}.

  (* TODO: maybe add frame after [we1] here *)
  Lemma OwnMemKey_Obs_extend a E h k we1 we2 :
    nclose DB_InvName ⊆ E →
    we_key we1 = we_key we2 →
    we1 ≠ we2 →
    GlobalInv -∗
    Obs a (h ++ [we1]) -∗
    k ↦ₖ Some we2 ={E}=∗
    k ↦ₖ Some we2 ∗
    ∃ hf, Obs DB_addr (h ++ [we1] ++ hf ++ [we2]).
  Proof.
    iIntros (HE Heq Hneq) "#HGinv #Hobs Hk".
    iMod (OwnMemKey_key with "[$HGinv][$Hk]") as "[Hk %Hkey]"; [solve_ndisj|].
    iMod (OwnMemKey_some_obs_we with "[$HGinv][$Hk]") as "[Hk (%h' & #Hobs' & %Hatkey)]"; [solve_ndisj|].
    iDestruct (Obs_compare with "Hobs Hobs'") as %Hle.
    destruct Hle as [Hle | Hle]; last first.
    { (* Solve contradiction *)
      iMod (OwnMemKey_obs_frame_prefix_some with "[$HGinv][$Hk $Hobs]")
        as "[Hk %Hatkey']"; [solve_ndisj|done..|].
      rewrite at_key_snoc_some in Hatkey'; naive_solver. }
    assert (Some we2 = at_key k h') as ->.
    { by rewrite Hatkey. }
    iMod (OwnMemKey_allocated with "[$HGinv][$Hk]") as "(%we' & Hk & %Hatkey' & %Hle')";
      [solve_ndisj|done|apply at_key_snoc_some; naive_solver|].
    assert (we' = we2) as -> by naive_solver. clear Hatkey'.
    iFrame "Hk".
    destruct Hle as [h'' ->].
    rewrite /at_key /hist_at_key in Hatkey.
    rewrite !filter_app in Hatkey.
    rewrite filter_cons_True in Hatkey; [|naive_solver].
    rewrite -app_assoc in Hatkey.
    rewrite last_app_cons in Hatkey.
    apply last_cons_ne in Hatkey; [|done].
    apply last_filter_postfix in Hatkey.
    destruct Hatkey as (yz & zs & -> & HP).
    iDestruct (Obs_get_smaller with "Hobs'") as "Hobs''".
    { rewrite !app_assoc. apply prefix_app_r. rewrite -!app_assoc. done. }
    by eauto.
  Qed.

End with_Σ.
